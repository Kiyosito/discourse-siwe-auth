import Route from "@ember/routing/route";

export default Route.extend({
  // Make sure the route is accessible even when not logged in
  beforeModel() {
    this.controllerFor("application").set("showFooter", false);
  },
});
