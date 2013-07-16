
Sequel.migration do
	change do
		create_table(:registry_settings) do
      primary_key :id
      foreign_key :registry_application_id , :registry_applications
      String :updated_at
      Integer :version, :default => 0
      String :comments , :text => true
      String :settings , :null => false , :text => true
    end
  end
end