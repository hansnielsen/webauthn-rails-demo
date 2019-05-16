class SupportWebAuthnRegistrations < ActiveRecord::Migration[5.2]
  def change
    add_column :registrations, :format, :integer

    reversible do |dir|
      dir.up do
        Registration.find_each do |r|
          r.format = :u2f
          r.public_key = Base64.urlsafe_encode64(Base64.decode64(r.public_key))
          r.save!
        end
      end

      dir.down do
        Registration.find_each do |r|
          r.public_key = Base64.strict_encode64(Base64.urlsafe_decode64(r.public_key))
          r.save!
        end
      end
    end
  end
end
