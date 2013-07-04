
Sequel.migration do
  change do
    create_table(:registry_applications) do
      primary_key :id 
      String :email , :null => false
      String :state  , :null => false , :default => 'PENDING'
      String :created_at , :null => false 
      String :updated_at
      String :comments , :text => true
      String :settings , :null => false , :text => true
    end
  end
end