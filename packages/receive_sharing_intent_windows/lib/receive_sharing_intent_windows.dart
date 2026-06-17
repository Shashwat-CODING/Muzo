// Copyright 2024 Muzo. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
//
// No-op Windows stub for receive_sharing_intent.
// Sharing intent from external apps is not available on Windows Desktop.

import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Windows stub for [ReceiveSharingIntent].
/// Returns empty lists / streams; sharing intent is not available on Windows.
class ReceiveSharingIntentWindows extends ReceiveSharingIntent {
  static void registerWith() {
    ReceiveSharingIntent.instance = ReceiveSharingIntentWindows();
  }

  @override
  Future<List<SharedMediaFile>> getInitialMedia() async => [];

  @override
  Stream<List<SharedMediaFile>> getMediaStream() => const Stream.empty();

  @override
  Future<dynamic> reset() async {}
}
