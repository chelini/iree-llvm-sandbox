//===-- PDL.cpp - Interoperability with PDL -------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Dialects/LinalgTransform/ScopedCtx.h"

namespace mlir {
namespace linalg {

ScopedContext *&ScopedContext::getCurrentScopedContext() {
  thread_local ScopedContext *context = nullptr;
  return context;
}

ScopedContext::~ScopedContext() {
  llvm::errs() << "---------------------> bye\n";
}

} // namespace linalg
} // namespace mlir
