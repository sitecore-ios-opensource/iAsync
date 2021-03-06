#import <JFFUtils/Blocks/JUContainersHelperBlocks.h>

#import <Foundation/Foundation.h>

@interface NSOrderedSet (BlocksAdditions)

//Calls block once for number from 0(zero) to (size_ - 1)
//Creates a new NSOrderedSet containing the values returned by the block.
+ (instancetype)setWithSize:(NSUInteger)size
                   producer:(JFFProducerBlock)block;

//Invokes block once for each element of self.
//Creates a new NSOrderedSet containing the values returned by the block.
- (instancetype)map:(JFFMappingBlock)block;

- (instancetype)forceMap:(JFFMappingBlock)block;

- (id)firstMatch:(JFFPredicateBlock)predicate;
- (BOOL)any:(JFFPredicateBlock)predicate;
- (BOOL)all:(JFFPredicateBlock)predicate;

//Invokes the block passing in successive elements from self,
//Creates a new NSSet containing those elements for which the block returns a YES value
- (instancetype)select:(JFFPredicateBlock)predicate;

@end
