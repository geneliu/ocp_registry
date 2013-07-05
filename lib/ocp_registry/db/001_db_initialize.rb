
Sequel.migration do
  change do
    create_table(:registry_applications) do
      primary_key :id ,:auto_increment => false, :type => String
      String :email , :null => false
      String :project , :null => false
      String :discription , :text => true
      String :state  , :null => false , :default => 'PENDING'
      String :created_at , :null => false 
      String :updated_at
      String :comments , :text => true
      String :settings , :null => false , :text => true
    end
  end
end