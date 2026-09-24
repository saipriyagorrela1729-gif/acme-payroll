module Api
  module V1
    class SalaryComponentSerializer
      def self.call(component)
        {
          id: component.id,
          name: component.name,
          kind: component.kind,
          amount: component.amount.to_s,
          position: component.position
        }
      end
    end
  end
end
