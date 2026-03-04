#ifndef YTTKHelloWorld_h
#define YTTKHelloWorld_h

#import "../../Core/YTTKModule.h"

/**
 * @class YTTKHelloWorld
 * @abstract Example module demonstrating the YTTKModule protocol.
 *
 * This serves as a template for creating new modules.
 * It simply logs a message when activated.
 *
 * To create a new module based on this template:
 * 1. Copy this folder and rename files
 * 2. Update moduleIdentifier, moduleName, moduleDescription
 * 3. Add your hooks inside a %group and call %init in activate
 * 4. Register in %ctor
 * 5. Add the .x file to Makefile
 */
@interface YTTKHelloWorld : NSObject <YTTKModule>
@end

#endif /* YTTKHelloWorld_h */
