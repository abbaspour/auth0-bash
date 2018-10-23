function (user, context, callback) { 
    console.log('login_success with user: ' + user + ', ctx: ' + JSON.stringify(ctx));
    callback(null, user, context);
}
