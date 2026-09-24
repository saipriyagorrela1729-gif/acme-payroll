require "rails_helper"

RSpec.describe User, type: :model do
  it "generates an api token on create" do
    expect(create(:user).api_token).to be_present
  end

  it "authenticates with the correct password" do
    user = create(:user, email: "hr@acme.example", password: "password123")

    expect(User.authenticate(email: "hr@acme.example", password: "password123")).to eq(user)
    expect(User.authenticate(email: "hr@acme.example", password: "nope")).to be_nil
    expect(User.authenticate(email: "missing@acme.example", password: "password123")).to be_nil
  end

  it "requires a unique email" do
    create(:user, email: "dup@acme.example")
    expect(build(:user, email: "dup@acme.example")).not_to be_valid
  end

  it "rotates the token" do
    user = create(:user)
    old_token = user.api_token

    user.regenerate_api_token!

    expect(user.reload.api_token).not_to eq(old_token)
  end
end
