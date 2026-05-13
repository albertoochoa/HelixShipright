# HelixShipright

A fulfillment operations console for ShipRight — the thing that replaces the
spreadsheet ops staff have been running orders through. It does four jobs:

1. shows the queue of orders that need staff action, grouped by where they
   are in the pipeline
2. moves orders forward through that pipeline, refusing transitions that
   don't make sense ("ship before approve", "cancel something already
   delivered")
3. fetches carrier tracking events on a background worker and pushes them
   to the open order page when they arrive — no manual refresh
4. lets staff approve, ship, or cancel many orders at once

> **TL;DR — boot it:** `cd HelixShipright && bin/setup`

## Built with

| Layer        | Choice                                                  |
|--------------|---------------------------------------------------------|
| Runtime      | Ruby 3.4.1 on Rails 8.0                                 |
| Database     | PostgreSQL 14                                           |
| Front-end    | Hotwire (Turbo Streams + Stimulus) via importmap        |
| Lifecycle    | [`aasm`](https://github.com/aasm/aasm) on `Order`       |
| Audit trail  | Custom polymorphic `AuditLog` + `Auditable` concern     |
| Identity     | Rails 8 generated auth (`bin/rails g authentication`)   |
| Test framework | RSpec, FactoryBot, Faker                              |

No Devise. No PaperTrail. No Tailwind. No Docker / Kamal / CI configs — the
brief said not to bother and I didn't.

## How to run it

The one-line setup script does everything end-to-end:

```bash
bin/setup
```

It will:

1. `bundle install` (idempotent)
2. `bin/rails db:prepare` — create the database, run migrations
3. `bin/rails db:seed` — create the staff account and roughly 18 orders
   spread across every state in the lifecycle (so the dashboard is populated
   the moment you sign in)
4. boot `bin/dev` at http://localhost:3000

For a non-interactive run (e.g. before running tests in CI), pass
`--skip-server`.

### Sign-in

```text
email:    staff@shipright.test
password: password1234
```

These come from `db/seeds.rb`. There is no public sign-up route — staff are
managed internally by spec.

## Tests

```bash
bundle exec rspec
```

There are 36 examples, all green. They lean on the parts of the system
that can actually break in surprising ways:

- the AASM state machine on `Order` — every legal transition, every
  guard, every illegal transition
- the audit-log side effect that's wired into the state machine
- the carrier adapter (`Carriers::FakeClient`) — determinism, error
  injection
- the background job (`SyncTrackingJob`) — idempotent re-runs, correct
  `retry_on` vs. `discard_on` policy
- the controller (`OrdersController`) — auth, state filter, friendly
  flash on invalid transitions, bulk-action partial failures

I deliberately did not write smoke tests for view markup or system specs
for the Turbo Stream broadcast itself (see "Known limits" below).

## Architecture, in one paragraph

`Order` owns its own lifecycle: AASM transitions live on the model, guarded
by data the model can introspect (`tracking_number_present?`). The controller
never assumes a transition will work — it asks the model whether the requested
event is currently permitted and falls back to a flash message when it
isn't. When the order ships, an AASM `after` hook enqueues `SyncTrackingJob`,
which talks to `Carriers::Client` (a thin facade in front of `FakeClient`
today, a real UPS/FedEx client tomorrow with a one-line swap). The job
upserts tracking rows keyed on the carrier's `external_id` so re-runs are
free, then fires a Turbo Stream broadcast — every open detail page for that
order swaps its timeline in without a reload. Audit logging is a separate
concern (`Auditable`) so the next model that needs it just has to include
the module.

## Choices I made

**State machine on the model, not a service object.**
The state machine *is* the model's business rule, not a piece of
orchestration. Keeping it on `Order` means `order.may_ship?` and
`order.aasm.events(permitted: true)` are first-class queries the view can
use directly to decide which buttons to render. The controller stays thin.

**Custom `AuditLog` + concern, not PaperTrail or audited.**
The brief explicitly flagged that audit history "may apply to other models
in the future," but right now we only need *state changes*, with the actor
and the from/to states. A polymorphic `audit_logs` table behind an
`Auditable` concern weighs nothing — it's about 30 lines of code total —
and stays under my control. PaperTrail's full version-diffing machinery is
more than we need.

**Sealed error hierarchy at the carrier boundary.**
`Carriers::Error` has four subclasses — `TimeoutError` and `ServerError`
are transient (the job retries), `InvalidPayload` and `NotFoundError` are
terminal (the job discards). That split is what lets `retry_on` /
`discard_on` Do The Right Thing without scattering rescue blocks.

**Integer cents for money.**
`price_cents`, `unit_price_cents`. Float arithmetic is a known foot-gun
for currency; postponing the decision until it actually matters seemed
worse than just doing it now. `LineItem#copy_price_from_product` snapshots
the unit price at create time, so changing a product's price later
doesn't quietly rewrite history on past orders.

**Hotwire over an SPA.**
The "background sync updates the page" requirement reads like it wants
WebSockets. Turbo Streams over Action Cable handle that natively in Rails,
and the rest of the UI is plain server-rendered ERB. An SPA would be more
JavaScript than this app needs to do its job.

**ActiveJob `:async` adapter in development.**
The seed file flips this to `:inline` so demo data is fully populated when
the script exits; everywhere else development just uses the in-process
async pool. Solid Queue is in the Gemfile and is the obvious production
target — flipping it on is a one-line config change.

## What I'd reach for next

- **Optimistic locking on `Order`.** Two staff members hitting "Approve"
  at the same time both succeed today (the second is a no-op, because AASM
  refuses the now-illegal transition). A `lock_version` column would turn
  that into an explicit `StaleObjectError` and a more honest error message.
- **A real policy layer.** Currently every authenticated user can do
  anything. Pundit + a simple `OrderPolicy` would let us split
  approver/shipper roles, which any real ops team needs.
- **Pagination and saved filters** on the orders index. Right now it
  returns every order in the table. At 10k orders this stops being
  useful — keyset pagination + a stored filter per user fixes it.
- **A system spec covering Turbo Stream broadcasts.** Capybara with the
  Action Cable test adapter would verify the full path end-to-end. The
  unit + request specs cover everything *up to* the broadcast.
- **Real Solid Queue for jobs**, with `bin/jobs` running as a worker
  process. One-line adapter change in `config/application.rb`.
- **Inventory.** Out of scope for the brief but obviously the next thing
  any fulfillment system needs — approving an order should validate that
  stock exists.

## Map of the source tree

```
HelixShipright/
├── app/
│   ├── controllers/orders_controller.rb       — index / show / transition / bulk_transition / sync_tracking
│   ├── jobs/sync_tracking_job.rb              — async carrier polling + Turbo broadcast
│   ├── models/
│   │   ├── order.rb                           — the AASM state machine lives here
│   │   ├── line_item.rb                       — snapshots price at create
│   │   ├── product.rb / tracking_event.rb / audit_log.rb
│   │   └── concerns/auditable.rb              — reusable polymorphic audit mixin
│   ├── services/carriers/
│   │   ├── client.rb                          — public facade everything else talks to
│   │   ├── fake_client.rb                     — deterministic simulator
│   │   ├── tracking_event_data.rb             — Ruby 3.2 Data.define value object
│   │   └── error.rb / timeout_error.rb / server_error.rb / invalid_payload.rb / not_found_error.rb
│   └── views/orders/
│       ├── index.html.erb                     — state filters + bulk-action form
│       ├── show.html.erb                      — turbo_stream_from the order
│       └── _tracking_timeline.html.erb        — Turbo replace target
├── db/seeds.rb                                — staff user + ~18 orders across every state
├── spec/                                      — RSpec coverage
├── BUILD-PROJECT.md                           — the recipe to recreate this repo from scratch
└── EXPLANATION.md                             — a code-level walkthrough
```

## Known limits

- **Concurrent transitions** aren't strictly locked. AASM refuses the
  losing transition cleanly, but a row-level lock would be honest.
- **The carrier "API" is faked.** Real integrations would have rate
  limits, webhook callbacks, and per-carrier auth. The facade has the
  right shape to accept a real adapter, but nothing's plugged in.
- **No order edit.** Staff can move orders through the pipeline but
  can't add / remove / edit line items after creation.
- **No order creation UI.** Seed data only. (The brief is a *dashboard*,
  not a checkout — but I'd add it before shipping this to real ops staff.)
