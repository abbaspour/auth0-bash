function (ctx, callback) {
  console.log('login_failure with ctx: ' + JSON.stringify(ctx));
  callback(null, ctx);
}
