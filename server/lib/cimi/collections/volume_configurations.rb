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
  class VolumeConfigurations < Base

    check_capability :for => lambda { |m| driver.respond_to? m }

    collection :volume_configurations do

      operation :index do
        description "Get list all VolumeConfigurations"
        param :CIMISelect,  :string,  :optional
        control do
          volume_configuration = VolumeConfigurationCollection.default(self).filter_by(params[:CIMISelect])
          respond_to do |format|
            format.xml { volume_configuration.to_xml }
            format.json { volume_configuration.to_json }
          end
        end
      end

      operation :show do
        description "Get a specific VolumeConfiguration"
        control do
          volume_config = VolumeConfiguration.find(params[:id], self)
          respond_to do |format|
            format.xml { volume_config.to_xml }
            format.json { volume_config.json }
          end
        end
      end
    end

  end
end
