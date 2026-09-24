require "rails_helper"

RSpec.describe SalaryComponent, type: :model do
  it { is_expected.to belong_to(:salary_record) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_inclusion_of(:kind).in_array(%w[earning deduction]) }
  it { is_expected.to validate_numericality_of(:amount).is_greater_than_or_equal_to(0) }

  it "knows earnings from deductions" do
    expect(build(:salary_component, kind: "earning")).to be_earning
    expect(build(:salary_component, kind: "deduction")).to be_deduction
  end
end
