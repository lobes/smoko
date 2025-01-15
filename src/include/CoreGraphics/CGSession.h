#ifndef CG_SESSION_H
#define CG_SESSION_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// CoreGraphics Session ID type
typedef int32_t CGSSessionID;

// Get the main connection ID
CGSSessionID CGSMainConnectionID(void);

// Lock the screen
int CGSSessionSecureConnections(CGSSessionID session);

#ifdef __cplusplus
}
#endif

#endif // CG_SESSION_H 