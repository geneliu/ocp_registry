Sequel.migration do
	change do
		#migration data
		self[:registry_settings].insert([:application_id, :settings, :comments, :updated_at],
    	self[:registry_applications].select(:id, :settings, :comments, :updated_at))
		#drop column
		alter_table(:registry_applications) do
			drop_column :comments
			drop_column :settings
		end
	end
end