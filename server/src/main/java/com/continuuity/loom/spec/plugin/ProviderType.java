/*
 * Copyright 2012-2014, Continuuity, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.continuuity.loom.spec.plugin;

import com.google.common.collect.Maps;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Map;

/**
 * A Provider type defines what parameters admins and users need to provide to a
 * {@link com.continuuity.loom.spec.Provider} in order for it to provide machines properly.
 */
public class ProviderType extends AbstractPluginSpecification {
  private static final Logger LOG = LoggerFactory.getLogger(ProviderType.class);

  public ProviderType(String name, String description, Map<ParameterType, ParametersSpecification> parameters,
                      Map<String, ResourceTypeSpecification> resourceTypes) {
    super(name, description, parameters, resourceTypes);
  }

  /**
   * Given a map of field name to value, filter out all fields that are not admin overridable fields or user fields,
   * and group fields by type. For example, sensitive fields will be grouped together, as will non sensitive fields.
   *
   * @param input Mapping of field name to value.
   * @return {@link PluginFields} containing fields grouped by type.
   */
  public PluginFields groupFields(Map<String, String> input) {
    PluginFields.Builder builder = PluginFields.builder();
    Map<String, FieldSchema> adminFields = getParametersSpecification(ParameterType.ADMIN).getFields();
    Map<String, FieldSchema> userFields = getParametersSpecification(ParameterType.USER).getFields();

    for (Map.Entry<String, String> entry : input.entrySet()) {
      String field = entry.getKey();
      String fieldVal = entry.getValue();

      // see if this is an overridable admin field
      FieldSchema fieldSchema = adminFields.get(field);
      if (fieldSchema == null || !fieldSchema.isOverride()) {
        // not an overridable admin field. check if its a user field
        fieldSchema = userFields.get(field);
      }

      // if its not a user field or an overridable admin field, ignore it
      if (fieldSchema != null) {
        if (fieldSchema.isSensitive()) {
          builder.putSensitive(field, fieldVal);
        } else {
          builder.putNonsensitive(field, fieldVal);
        }
      } else {
        LOG.info("Ignoring field {} as its not an overridable admin field or user field.", field);
      }
    }
    return builder.build();
  }
}
