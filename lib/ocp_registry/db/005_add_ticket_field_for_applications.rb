Sequel.migration do 
	change do 
		alter_table(:registry_applications) do
			add_column :ticket , String, :null => true, :default => nil
		end
 	end
end