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

import com.google.common.base.Objects;
import com.google.common.base.Preconditions;

import java.util.Set;

/**
 * A description of some field that the corresponding provisioner plugin understands, defining what type of value is
 * expected for the field.
 */
public class FieldSchema {
  private final String label;
  private final String type;
  private final String tip;
  private final Set<String> options;
  private final String defaultValue;
  private final boolean override;

  private FieldSchema(String label, String type, String tip, Set<String> options, String defaultValue,
                      Boolean override) {
    Preconditions.checkArgument(type != null, "Field type must be specified.");
    Preconditions.checkArgument(label != null && !label.isEmpty(), "Field label must be specified.");
    this.type = type;
    this.label = label == null ? "" : label;
    this.tip = tip == null ? "" : tip;
    this.override = override == null ? false : override;
    this.options = options;
    this.defaultValue = defaultValue;
  }

  /**
   * Get the user friendly label for the field.
   *
   * @return User fiendly label for the field.
   */
  public String getLabel() {
    return label;
  }

  /**
   * Get the type of value expected for the field. Includes "text", "password", "select", etc.
   *
   * @return Type of value expected for the field.
   */
  public String getType() {
    return type;
  }

  /**
   * Get the tip or user friendly description of the field.
   *
   * @return Tip or user friendly description of the field.
   */
  public String getTip() {
    return tip;
  }

  /**
   * Get the possible values the field can take if the type of field is "select". Null if not applicable.
   *
   * @return Possible values the field can take if the type of field is "select". Null if not applicable.
   */
  public Set<String> getOptions() {
    return options;
  }

  /**
   * Get the default value for the field that should be used. Null if not applicable.
   *
   * @return Default value for the field that should be used. Null if not applicable.
   */
  public String getDefaultValue() {
    return defaultValue;
  }

  /**
   * Get whether or not the admin defined value can be overwritten by the user.
   *
   * @return Whether or not the admin defined value can be overwritten by the user.
   */
  public boolean getOverride() {
    return override;
  }

  /**
   * Get a builder for creating a field schema.
   *
   * @return Builder for creating a field schema.
   */
  public static Builder builder() {
    return new Builder();
  }

  /**
   * Builds a {@link FieldSchema}. Used so that optional fields don't have to be sent to a constructor and so that its
   * clear what fields are being set.
   */
  public static class Builder {
    private String label;
    private String type;
    private String tip;
    private Set<String> options;
    private String defaultValue;
    private Boolean override;

    public Builder setLabel(String label) {
      this.label = label;
      return this;
    }

    public Builder setType(String type) {
      this.type = type;
      return this;
    }

    public Builder setTip(String tip) {
      this.tip = tip;
      return this;
    }

    public Builder setOptions(Set<String> options) {
      this.options = options;
      return this;
    }

    public Builder setDefaultValue(String defaultValue) {
      this.defaultValue = defaultValue;
      return this;
    }

    public Builder setOverride(Boolean override) {
      this.override = override;
      return this;
    }

    public FieldSchema build() {
      return new FieldSchema(label, type, tip, options, defaultValue, override);
    }
  }

  @Override
  public boolean equals(Object o) {
    if (this == o) {
      return true;
    }
    if (!(o instanceof FieldSchema)) {
      return false;
    }

    FieldSchema that = (FieldSchema) o;

    return Objects.equal(defaultValue, that.defaultValue) &&
      Objects.equal(label, that.label) &&
      Objects.equal(options, that.options) &&
      Objects.equal(override, that.override) &&
      Objects.equal(tip, that.tip) &&
      Objects.equal(type, that.type);
  }

  @Override
  public int hashCode() {
    return Objects.hashCode(label, type, tip, options, defaultValue, override);
  }

  @Override
  public String toString() {
    return Objects.toStringHelper(this)
      .add("label", label)
      .add("type", type)
      .add("tip", tip)
      .add("options", options)
      .add("default", defaultValue)
      .add("override", override)
      .toString();
  }
}