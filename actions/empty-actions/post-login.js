exports.onExecutePostLogin = async (event, api) => {
  console.log('User logging in: ' + event.user.email);
};