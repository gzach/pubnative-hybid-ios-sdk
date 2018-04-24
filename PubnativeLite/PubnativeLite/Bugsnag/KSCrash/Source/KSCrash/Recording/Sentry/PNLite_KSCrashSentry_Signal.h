//
//  Copyright © 2018 PubNative. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

/* Catches fatal unix signals.
 */

#ifndef HDR_PNLite_KSCrashSentry_Signal_h
#define HDR_PNLite_KSCrashSentry_Signal_h

#ifdef __cplusplus
extern "C" {
#endif

#include "BSG_KSCrashSentry.h"

/** Install our custom signal handler.
 *
 * @param context The crash context to fill out when a crash occurs.
 *
 * @return true if installation was succesful.
 */
bool bsg_kscrashsentry_installSignalHandler(BSG_KSCrash_SentryContext *context);

/** Uninstall our custom signal handlers and restore the previous ones.
 */
void bsg_kscrashsentry_uninstallSignalHandler(void);

#ifdef __cplusplus
}
#endif

#endif // HDR_KSCrashSentry_Signal_h
