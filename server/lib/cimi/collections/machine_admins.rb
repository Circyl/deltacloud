# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.  The
# ASF licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the
# License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations
# under the License.

module CIMI::Collections
  class MachineAdmins < Base

    check_capability :for => lambda { |m| driver.respond_to? m }

    collection :machine_admins do
      description 'Machine Admin entity'

      operation :index do
        description "List all machine admins"
        param :CIMISelect,  :string,  :optional
        control do
          machine_admins = MachineAdminCollection.default(self).filter_by(params[:CIMISelect])
          respond_to do |format|
            format.xml { machine_admins.to_xml }
            format.json { machine_admins.to_json }
          end
        end
      end

      operation :show do
        description "Show specific machine admin"
        control do
          machine_admin = MachineAdmin.find(params[:id], self)
          respond_to do |format|
            format.xml { machine_admin.to_xml }
            format.json { machine_admin.to_json }
          end
        end
      end

      operation :create do
        description "Show specific machine admin"
        control do
          if request.content_type.end_with?("+json")
            new_admin = MachineAdmin.create_from_json(request.body.read, self)
          else
            new_admin = MachineAdmin.create_from_xml(request.body.read, self)
          end
          status 201 # Created
          respond_to do |format|
            format.json { new_admin.to_json }
            format.xml { new_admin.to_xml }
          end
        end
      end

      operation :delete do
        description "Delete specified MachineAdmin entity"
        control do
          MachineAdmin.delete!(params[:id], self)
          no_content_with_status(200)
        end
      end

    end

  end
end
