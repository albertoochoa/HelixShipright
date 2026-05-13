module AuthenticationHelpers
  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: "password1234" }
  end
end

RSpec.configure do |config|
  config.include AuthenticationHelpers, type: :request
end
