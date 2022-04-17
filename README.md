# WebAuthn Rails demo application

This demo is part of a [blog post](https://www.stackallocated.com/blog/2019/u2f-to-webauthn/) that describes how to migrate an application from Rails to WebAuthn.

This repository has been archived as it is unlikely to ever need changes again. Chrome has successfully disabled support for the classic FIDO U2F API ("Cryptotoken") as of February 2022.

While you'd be best served reading the blog post, the tl;dr is:

1. Try out the app when it only supports U2F (see the tag `u2f-only`)
2. Switch U2F signing to WebAuthn (see the tag `sign-with-webauthn`)
3. Migrate the database to support distinguishing U2F vs WebAuthn (see the tag `db-migration`)
4. Switch registration to WebAuthn only (see the tag `full-webauthn`)

# Running the demo application

These instructions are good for any commit in this repo.

1. Generate TLS certificates:
   ```
   mkcert -install
   mkcert -cert-file config/tls/localhost.pem -key-file config/tls/localhost-key.pem localhost
   ```

2. Run `rake db:migrate`

3. Run `rails s` to start it!
