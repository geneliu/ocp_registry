module Ocp::Registry

    class CloudManager

        class Openstack

            module NeutronHelper

                NEUTRON_QUOTA_FIELDS = ["network", 
                                        "router",
                                        "port",
                                        "subnet",
                                        "floatingip",
                                        "security_group",
                                        "security_group_rule"]

                NEUTRON_NETWORK_FIELDS = ['vlan_id', 
                                        'network_name',
                                        'subnet_name',
                                        'network_address',
                                        'gateway_ip',
                                        'allocation_pools',
                                        'dns_name_servers']

                def default_network_quota
                    # TODO Currently there is no way to get neutron default quotas, see line 122 of
                    # https://github.com/openstack/horizon/blob/stable/havana/openstack_dashboard/dashboards/admin/projects/views.py
                    # You can neither find get_quotas_defaults API in Fog::Network
                    {
                        "network" => 1,
                        "router" => 0,
                        "port" => 50,
                        "subnet" => 10,
                        "floatingip" => 0,
                        "security_group" => 10,
                        "security_group_rule" => 100
                    }
                end

                def set_network_quota(tenant_id, hash)
                    with_openstack do 
                        settings = Ocp::Registry::Common.hash_filter(hash, NEUTRON_QUOTA_FIELDS)
                        network.update_quota(tenant_id, settings).body['quota']
                    end
                end

                def create_network(tenant_id, hash)
                    ret = {'network'=> nil, 'subnet' => nil}

                    # == step 0: make input clean ==
                    settings = {}
                    NEUTRON_NETWORK_FIELDS.each do |k|
                        v = hash[k]
                        if v.nil? || v.empty? || v.strip.empty?
                            settings[k] = nil
                        else
                            settings[k] = v
                        end
                    end

                    vlan_id = settings['vlan_id']
                    network_name = settings['network_name']
                    subnet_name = settings['subnet_name']
                    network_address = settings['network_address']
                    gateway_ip = settings['gateway_ip']
                    allocation_pools = Ocp::Registry::Common.parse_ip_range_per_line settings['allocation_pools']
                    dns_name_servers = Ocp::Registry::Common.parse_ip_addr_per_line settings['dns_name_servers']

                    # == step 1: create neutron network ==
                    return  if !network_name
                    # what if we create a same-name network? result: same-name network can co-exist
                    ret['network'] = net = network.create_network(:name => network_name,  
                                                :shared => false,
                                                :tenant_id => tenant_id,
                                                :provider_network_type => 'vlan',
                                                :provider_physical_network => 'physnet1',
                                                :provider_segmentation_id => vlan_id).body['network']

                    # == setp 2: create subnet ==
                    return ret if !subnet_name
                    # check https://github.com/fog/fog/blob/master/lib/fog/openstack/requests/network/create_subnet.rb for arguments
                    ret['subnet'] = subnet = network.create_subnet(net['id'], network_address, 4, {
                            :name => subnet_name,
                            :gateway_ip => gateway_ip,
                            :allocation_pools => allocation_pools,
                            :dns_nameservers => dns_name_servers,
                            :tenant_id => tenant_id
                        })

                    # == step 3: open security groups ==
                    default_sg = network.list_security_groups(:tenant_id => tenant_id).body['security_groups'][0]
                    default_sg['security_group_rules'].each do |sgr|
                        network.delete_security_group_rule(sgr['id'])
                    end
                    network.create_security_group_rule(default_sg['id'], 'egress', {
                        :tenant_id => tenant_id
                        })
                    network.create_security_group_rule(default_sg['id'], 'ingress', {
                        :tenant_id => tenant_id
                        })

                    return ret
                end

            end

        end

    end

end
