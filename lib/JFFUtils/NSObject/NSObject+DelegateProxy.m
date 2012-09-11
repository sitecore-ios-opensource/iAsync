#import "NSObject+DelegateProxy.h"

#import "JFFAssignProxy.h"
#import "JFFMutableAssignArray.h"

#import "NSObject+RuntimeExtensions.h"
#import "NSString+PropertyName.h"

#include <objc/message.h>
#include <objc/runtime.h>

static char proxyDelegatesKey;
static char realDelegateKey;

static void validateArguments(id proxy,
                              NSString *delegateName,
                              id targetObject)
{
    assert([delegateName length]>0);
    assert(proxy);
    assert(targetObject);

    //should has a property getter
    assert([[targetObject class] hasInstanceMethodWithSelector:NSSelectorFromString(delegateName)]);
    //should has a property setter
    assert([[targetObject class] hasInstanceMethodWithSelector:NSSelectorFromString([delegateName propertySetNameForPropertyName])]);
}

@implementation NSString (DelegateProxy)

- (NSString*)hookedGetterMethodNameForClass:(Class)targetClass
{
    NSString *result = [[NSString alloc]initWithFormat:@"hookedDelegateGetterName_%@_%@",
                        targetClass,
                        self];
    return result;
}

- (NSString*)hookedSetterMethodNameForClass:(Class)targetClass
{
    NSString *result = [[NSString alloc]initWithFormat:@"hookedDelegateSetterName_%@_%@",
                        targetClass,
                        self];
    return result;
}

@end

@interface NSObject (DelegateProxyPrivate)

@property (nonatomic, weak) id realDelegateWeakObject;

- (JFFMutableAssignArray*)lazyProxyDelegatesWeakMutableArray;
- (JFFMutableAssignArray*)lazyRealDelegateWeakMutableArray;

@end

@interface JFFDelegateProxyClassMethods : NSObject
@end

@implementation JFFDelegateProxyClassMethods

- (id)delegateGetterHookMethod
{
    NSString *delegateName = NSStringFromSelector(_cmd);
    NSArray *delegateNameComponents = [delegateName componentsSeparatedByString:@"_"];
    NSString *hookedGetterName = [[delegateNameComponents lastObject]hookedGetterMethodNameForClass:[self class]];
    return objc_msgSend(self, NSSelectorFromString(hookedGetterName));
}

- (id)delegateSetterHookMethod:(id)delegate
{
    NSString *delegateName = NSStringFromSelector(_cmd);
    NSArray *delegateNameComponents = [delegateName componentsSeparatedByString:@"_"];
    NSString *hookedSetterName = [[delegateNameComponents lastObject]hookedSetterMethodNameForClass:[self class]];
    return objc_msgSend(self, NSSelectorFromString(hookedSetterName), delegate);
}

@end

@implementation NSObject (DelegateProxy)

- (JFFMutableAssignArray*)lazyProxyDelegatesWeakMutableArray
{
    if (!objc_getAssociatedObject(self, &proxyDelegatesKey))
    {
        objc_setAssociatedObject(self, &proxyDelegatesKey, [JFFMutableAssignArray new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return objc_getAssociatedObject(self, &proxyDelegatesKey);
}

- (id)realDelegateWeakObject
{
    JFFAssignProxy *resultProxy = objc_getAssociatedObject(self, &realDelegateKey);
    return resultProxy.target;
}

- (void)setRealDelegateWeakObject:(id)delegate
{
    JFFAssignProxy *proxy = [[JFFAssignProxy alloc]initWithTarget:delegate];
    objc_setAssociatedObject(self, &realDelegateKey, proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)addDelegateProxy:(id)proxy
            delegateName:(NSString *)delegateName
{
    validateArguments(proxy, delegateName, self);

    Class prototypeClass = [JFFDelegateProxyClassMethods class];

    {
        NSString *prototypeMethodName = [[NSString alloc]initWithFormat:@"prototypeDelegateGetterName_%@_%@",
                                         [self class],
                                         delegateName];
        NSString *hookedGetterName = [delegateName hookedGetterMethodNameForClass:[self class]];

        if ([prototypeClass addInstanceMethodIfNeedWithSelector:@selector(delegateGetterHookMethod)
                                                        toClass:prototypeClass
                                              newMethodSelector:NSSelectorFromString(prototypeMethodName)])
        {
            [prototypeClass hookInstanceMethodForClass:[self class]
                                          withSelector:NSSelectorFromString(delegateName)
                               prototypeMethodSelector:NSSelectorFromString(prototypeMethodName)
                                    hookMethodSelector:NSSelectorFromString(hookedGetterName)];
        }
    }

    {
        delegateName = [delegateName propertySetNameForPropertyName];
        NSString *prototypeMethodName = [[NSString alloc]initWithFormat:@"prototypeDelegateSetterName_%@_%@",
                                         [self class],
                                         delegateName];
        NSString *hookedSetterName = [delegateName hookedSetterMethodNameForClass:[self class]];

        if ([prototypeClass addInstanceMethodIfNeedWithSelector:@selector(delegateSetterHookMethod:)
                                                        toClass:prototypeClass
                                              newMethodSelector:NSSelectorFromString(prototypeMethodName)])
        {
            [prototypeClass hookInstanceMethodForClass:[self class]
                                          withSelector:NSSelectorFromString(delegateName)
                               prototypeMethodSelector:NSSelectorFromString(prototypeMethodName)
                                    hookMethodSelector:NSSelectorFromString(hookedSetterName)];
        }
    }
}

- (void)removeDelegateProxy:(id)proxy
               delegateName:(NSString *)delegateName
{
    validateArguments(proxy, delegateName, self);

    [self doesNotRecognizeSelector:_cmd];
}

@end
