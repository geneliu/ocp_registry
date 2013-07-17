Sequel.migration do 
	change do 
		alter_table(:registry_settings) do
			add_column :from , String, :null => false, :default => 'USER'
		end
		settings = self[:registry_settings].select(:id,:version)
		admins = []
		settings.each do |set|
			admins <<  set[:id] if (set[:version] & 1) == 1
		end
		self[:registry_settings].where(:id => admins).update(:from => 'ADMIN')
 	end
end