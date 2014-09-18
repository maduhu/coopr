/**
 * TemplateFormCtrl
 * handles both "edit" and "create" views
 */

angular.module(PKG.name+'.controllers').controller('TemplateFormCtrl', 
function ($scope, $state, $alert, $q, myApi, CrudFormBase) {
  CrudFormBase.apply($scope);

  if($scope.editing) {
    $scope.model = myApi.Template.get($state.params);
    $scope.model.$promise['catch'](function () { $state.go('404'); });
  }
  else {
    $scope.model = new myApi.Template();
  }

  $scope.tabs = [
    {title: 'General',        partial: '/partials/templates/form-tabs/general.html'},
    {title: 'Compatibility',  partial: '/partials/templates/form-tabs/compatibility.html'},
    {title: 'Defaults',       partial: '/partials/templates/form-tabs/defaults.html'},
    {title: 'Constraints',    partial: '/partials/templates/form-tabs/constraints.html'},
  ];
  $scope.tabs.activeTab = 0;

  $scope.nextTab = function () {
    $scope.tabs.activeTab = Math.min($scope.tabs.activeTab+1, $scope.tabs.length);
  }
});