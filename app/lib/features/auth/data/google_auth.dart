// Google sign-in (v7 API on mobile/web): incremental scopes, silent token refresh.
// Supports multiple signed-in accounts simultaneously.
//
// Startup restore is silent. It reuses unexpired stored tokens and asks the
// platform for a token bound to each stored account with prompting disabled.
// It never calls attemptLightweightAuthentication, which on Android can show
// the Credential Manager account picker at every launch.
//
// The implementation is split across `part` files under `google_auth/`
// while this file stays the public entry point.
//
// PRIVACY: never log tokens, refresh tokens, emails, account ids,
// authorization codes, or raw plugin/auth exception text.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/safe_storage.dart';
import '../domain/account_email.dart';
import '../domain/google_token_policy.dart';

part 'google_auth/base.dart';
part 'google_auth/init.dart';
part 'google_auth/sign_in.dart';
part 'google_auth/token.dart';
part 'google_auth/account.dart';

class GoogleAuthException implements Exception {
  GoogleAuthException(this.message);
  final String message;
  @override
  String toString() => 'GoogleAuthException: $message';
}

class GoogleAuth extends _GoogleAuthBase
    with
        _GoogleAuthInit,
        _GoogleAuthSignIn,
        _GoogleAuthToken,
        _GoogleAuthAccount {
  GoogleAuth({
    super.storage,
    @visibleForTesting super.silentAuthorizer,
    @visibleForTesting super.initializePlatform,
  });
}
