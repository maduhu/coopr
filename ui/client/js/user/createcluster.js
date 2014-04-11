/**
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

/**
 * CreateCluster module, sets up namespace, depends on AngularJS.
 * @type {Object}
 */
var CreateCluster = {};

CreateCluster.app = angular.module('createcluster', ['ngSanitize'], ['$interpolateProvider',
  function ($interpolateProvider) {
  $interpolateProvider.startSymbol('[[');
  $interpolateProvider.endSymbol(']]');
}]);

CreateCluster.app.value('fetchUrl', '/pipeApiCall?path=');

CreateCluster.app.factory('dataFactory', ['$http', '$q', 'fetchUrl',
  function ($http, $q, fetchUrl) {
    var clusterId = $("#user-cluster-id").val();
    return {
      getClusterId: function () {
        return clusterId;
      },
      getClusterDefinition: function (clusterId, callback) {
        $http.get(fetchUrl + '/clusters/' + clusterId).success(callback);
      },
      getClusterTemplate: function (templateId, callback) {
        $http.get(fetchUrl + '/clustertemplates/' + templateId).success(callback);
      },
      getProviders: function (callback) {
        $http.get(fetchUrl + '/providers').success(callback);
      }
    };
}]);
 
CreateCluster.app.controller('CreateClusterCtrl', ['$scope', '$interval', 'dataFactory',
  function ($scope, $interval, dataFactory) {
  $scope.configDiv = $('#inputConfig')[0];
  PP.registerPrettifier($scope.configDiv);
  $scope.clusterId = dataFactory.getClusterId();

  $scope.showAdvanced = false;
  $scope.allowedProviders = [];
  $scope.allowedHardwareTypes = [];
  $scope.allowedImageTypes = [];
  $scope.allowedServices = [];

  $scope.leaseDuration = {
    initial: {},
    max: {},
    step: {}
  };
  $scope.notification = '';


  dataFactory.getProviders(function (providers) {
    $scope.allowedProviders = providers.map(function (provider) {
      return provider.name;
    });
  });
  
  /**
   * Watches clusterTemplateId and changes advanced settings based on selected value. Registers a
   * listener.
   */
  $scope.$watch('clusterTemplateId', function () {
    if ($scope.clusterTemplateId && !$scope.clusterId) {
      dataFactory.getClusterTemplate($scope.clusterTemplateId, function (template) {
        $scope = CreateCluster.addTemplateToScope(template, $scope);
      });
    }
  });

  // Get cluster data and load into existing cluster definition.
  if ($scope.clusterId) {
    dataFactory.getClusterDefinition($scope.clusterId, function (cluster) {
      $scope.clusterName = cluster.name;
      $scope.clusterNumMachines = cluster.nodes.length;
      $scope.clusterTemplateId = cluster.clusterTemplate.name;
      $scope = CreateCluster.addTemplateToScope(cluster.clusterTemplate, $scope);
    });
  }

  /**
   * Shows advanced settings.
   */
  $scope.toggleAdvanced = function () {
    $scope.showAdvanced = !$scope.showAdvanced;
  };

  /**
   * Adds an entry to an array, utility function to add a variety of values.
   * @param {String} name string to add.
   * @param {Array} arr  base array.
   */
  $scope.addEntry = function (name, arr) {
    Helpers.checkAndAdd(name, arr);
  };

  /**
   * Removes entry from collection if it doesn't exist.
   * @param {String} name string to add.
   * @param {Array} arr  base array.
   */
  $scope.removeEntry = function (name, arr) {
    Helpers.checkAndRemove(name, arr);
  };

  /**
   * Submits a request to create or update a cluster.
   * @param  {Object} $event generated by the form submission.
   */
  $scope.submitData = function ($event) {
    $event.preventDefault();
    $scope.notification = '';
    if (!$scope.template) {
      $scope.notification = 'Template is empty.';
      return;
    }
    var postJson = {
      name: $scope.clusterName,
      clusterTemplate: $scope.clusterTemplateId,
      numMachines: $scope.clusterNumMachines,
      provider: $scope.defaultProvider,
      hardwaretype: $scope.defaultHardwareType,
      imagetype: $scope.defaultImageType,
      services: $scope.selectedServices,
      initialLeaseDuration: $scope.leaseDuration.initial
    };
    if ($scope.defaultConfig) {
      if (!Helpers.isValidJSON($scope.defaultConfig)) {
        $scope.notification = Helpers.JSON_ERR;
        return;
      }
      postJson.config = $.extend({}, JSON.parse($scope.defaultConfig));
    }
    postJson.initialLeaseDuration = Helpers.concatMilliseconds(
      $scope.leaseDuration.initial);
    if ($scope.template.administration.leaseduration.initial !== 0 &&
      $scope.template.administration.leaseduration.initial 
      < postJson.initialLeaseDuration) {
      $("#notification").text('You cannot initially request a longer lease.');
      $("html, body").animate({ scrollTop: 0 }, "slow");
      return;
    }
    Helpers.submitPost($event, postJson, '/user/clusters');
  };
}]);

/**
 * Adds cluster template data to an existing scope.
 * @param {Object} template Cluster template definition.
 * @param {Object} scope CreateClusterCtrl scope.
 */
CreateCluster.addTemplateToScope = function (template, scope) {
  scope.template = template;
  scope.allowedHardwareTypes = template.compatibility.hardwaretypes;
  scope.allowedImageTypes = template.compatibility.imagetypes;
  scope.allowedServices = template.compatibility.services;
  scope.selectedServices = template.defaults.services;
  scope.defaultProvider = template.defaults.provider;
  scope.defaultHardwareType = template.defaults.hardwaretype;
  scope.defaultImageType = template.defaults.imagetype;
  scope.defaultConfig = JSON.stringify(template.defaults.config);
  if ('administration' in template) {
    scope.leaseDuration.initial = Helpers.parseMilliseconds(
      template.administration.leaseduration.initial);
  }

  // Prettify the json config
  PP.prettify(scope.configDiv, 1000);

  return scope;
};


