/**
 * myServicePicker
 *
 * similar to myThingPicker, but with extra stuff specifically for services
 *
 * share the style and template with myThingPicker
 */

var module = angular.module(PKG.name+'.directives');

module.constant('MYSERVICEPICKER_EVENT', {
  manage: 'myservicepicker-manage'
});

module.directive('myServicePicker', 
function myServicePickerDirective (MYSERVICEPICKER_EVENT) {
  return {
    restrict: 'E',
    templateUrl: 'thingpicker/thingpicker.html',
    replace: true,

    scope: {
      model: '=', // an array of names
      available: '=', // an array of strings, or of objects with name & description keys
      clusterId: '=', // id to use for management dropdown
      allowRm: '=' // allow removal boolean
    },

    controller: function ($scope, myApi) {

      $scope.thingName = "service";

      $scope.rmService = function (what) {
        $scope.model = $scope.model.filter(function (name) {
          return name !== what;
        });
      };

      $scope.addService = function (name) {
        $scope.model.push(name);
      };

      $scope.manageService = function (action, name) {
        myApi.ClusterService[action]( {clusterId: $scope.clusterId}, {name: name}, function () {
          $scope.$parent.$emit(MYSERVICEPICKER_EVENT.manage, action, name);
        });
      };

      $scope.$watchCollection('model', function(newVal) {
        remapAddables($scope.available, newVal);
        remapActionables(newVal);
      });

      $scope.$watchCollection('available', function(newVal) {
        remapAddables(newVal, $scope.model);
      });


      function remapAddables (available, avoidable) {
        $scope.addDropdown = (available||[]).reduce(function (out, svc) {
          var name = svc.name || svc; // in case available is an array of strings
          if((avoidable||[]).indexOf(name)===-1) {
            out.push({
              text: name,
              click: 'addService("'+name+'")'
            });
          }
          return out;
        }, []);
      }

      function remapActionables (visible) {
        $scope.actionDropdowns = (visible||[]).reduce(function (out, name) {
          if(name !== 'base') { // "base" cannot be removed nor managed, so it gets no dropdown

            var dd = [];

            if($scope.clusterId) { // "management mode"
              dd.push({
                text: '<span class="fa fa-fw fa-play"></span> Start',
                click: 'manageService("start", "'+name+'")'
              });
              dd.push({
                text: '<span class="fa fa-fw fa-stop"></span> Stop',
                click: 'manageService("stop", "'+name+'")'
              });
              dd.push({
                text: '<span class="fa fa-fw fa-undo"></span> Restart',
                click: 'manageService("restart", "'+name+'")'
              });

              if($scope.allowRm) {
                dd.push({ divider: true });
              }
            }

            if($scope.allowRm) {
              dd.push({
                text: '<span class="fa fa-fw fa-remove"></span> Remove',
                click: 'rmService("'+name+'")'
              });            
            }

            out[name] = dd;

          }
          return out;
        }, {});
      }


    }
  };
});
