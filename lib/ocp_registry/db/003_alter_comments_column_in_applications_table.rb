Sequel.migration do
	change do
		#migration data
		self[:registry_settings].insert([:registry_application_id, :settings, :comments, :updated_at],
    	self[:registry_applications].select(:id, :settings, :comments, :updated_at))
		#drop column
		alter_table(:registry_applications) do
			drop_column :comments
			drop_column :settings
			drop_column :updated_at
		end
	end
end