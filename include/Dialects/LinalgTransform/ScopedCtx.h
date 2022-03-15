//===-- PDL.h - Interoperability with PDL ---------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef IREE_LLVM_SANDBOX_DIALECTS_LINALGTRANSFORM_TRANSFORMS_SCOPED_CTX_H
#define IREE_LLVM_SANDBOX_DIALECTS_LINALGTRANSFORM_TRANSFORMS_SCOPED_CTX_H

#include "mlir/Support/Timing.h"

namespace mlir {
namespace linalg {

class ScopedContext {
public:
  ScopedContext() : tm(new DefaultTimingManager()) {
    ScopedContext::getCurrentScopedContext() = this;
  };
  ScopedContext(const ScopedContext &) = delete;
  ScopedContext &operator=(const ScopedContext &) = delete;
  ~ScopedContext();

  static ScopedContext *&getCurrentScopedContext();

  std::unique_ptr<DefaultTimingManager> tm;

};

} // namespace linalg
} // namespace mlir

#endif // IREE_LLVM_SANDBOX_DIALECTS_LINALGTRANSFORM_TRANSFORMS_SCOPED_CTX_H
