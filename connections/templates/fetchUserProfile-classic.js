function(access_token, ctx, callback){
    'use strict';

    console.log('auth0-to-auth0 fetchUserProfile with ctx: ' + JSON.stringify(ctx));

    const ruleName = 'auth0-to-auth0';
    const jsonwebtoken = require('jsonwebtoken@7.1.9'); // todo: 8.4.0

    if (!ctx.id_token) {
        return callback('missing-id_token');
    }

    const jwt = jsonwebtoken.decode(ctx.id_token);

    if (!jwt) {
        return callback('malformed-id_token');
    }

    if (!jwt.sub) {
        return callback('missing-sub');
    }

    if (!jwt.email) {
        return callback('missing-email');
    }

    const profile = {
         user_id: jwt.sub,
         email: jwt.email,
         given_name: jwt.given_name,
         family_name: jwt.family_name,
         root_txId: 3456,
         user_metadata: {
             txId: 1234,
             hobby: 'surfing'
         },
         app_metadata: {
             plan: 'full'
         }
    };

    if (jwt.picture) {
        profile.picture = jwt.picture;
    }

    return callback(null, profile);
}
