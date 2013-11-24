# iAsync - a better dispatch_async()
iAsync is ***a set of IOS libraries*** that aims to make asychronous programming easy for for **Objective-C** developers. 
It uses **functional programming** ideas to solve **Callback Hell** problem.




```
License : BSD
Supports iOS versions 4.0 and higher. Builds using IOS SDK ver. 5.0
```

## Callback Hell Problem
You are suffering from the callback hell if you have a lot of nested asynchronous calls in your project. For example :
![Callback Hell](https://github.com/EmbeddedSources/iAsync/raw/readme/readme/1-Callback-Hell.png)

This makes your code hard error prone. It is hard to debug and maintain such codebase. 
There is a nice [blogpost](http://tirania.org/blog/archive/2013/Aug-15.html) and a [webinar](http://blog.xamarin.com/csharp-async-on-ios-and-android/) by [Miguel de Icaza](https://github.com/migueldeicaza) .

Let's compare iAsync and the traditional approach 


## Weather application core task
This library aims to provide a more convenient task scheduler. Its main advantage is more elegant processing of operations with dependencies.

Let's consider an example weather application core. In order to get the weather by address we should perform the following  actions :

1. Query location from the geocoding service
2. Parse latitude and longitude data
3. Query weather using latitude and longitude data
4. Parse weather info 
5. Update UI


### Traditional approach with dispatch_async() and AFNetworking
```
// objective-c

NSString* geolocationUrl = [ NSString stringWithFormat: @"http://maps.googleapis.com/maps/api/geocode/json?sensor=true&address=%@", @"Kiev"];

AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
[manager GET:geolocationUrl parameters:nil success:^(AFHTTPRequestOperation *operation, id jsonLocation) {
    dispatch_async( myBackgroundQueue, ^{
            NSError* parseError;
    
            id<AWCoordinatesParser> parser = [ AWParserFactory jsonCoordinatesParser ];
            AWCoordinates* coordinates = [ parser parseData: jsonLocation
                                                      error: &parseError ];
            if ( !coordinates )                                          
            {
                 [ self handleError: parseError ];
            }                                          
                                                     
            NSString* weatherUrl = [ NSString stringWithFormat: @"http://api.openweathermap.org/data/2.5/weather?lat=%1.2f&lon=%1.2f", coordinates.latitude, coordinates.longitude ];
            
            
            [manager GET:weatherUrl parameters:nil success:^(AFHTTPRequestOperation *operation, id jsonWeather) {
                  dispatch_async( myBackgroundQueue, ^{
                        NSError* parseError;
                        id<AWWeatherParser> parser = [ AWParserFactory jsonWeatherParser ];
                        AWWeatherInfo* weather = [ parser parseData: weatherJson
                                                              error: &parseError ];
                        if ( !weather )                                          
                        {
                            [ self handleError: parseError ];
                        }                                          
                        
                        dispatch_async( dispatch_get_main_queue(), ^{
                           [ self updateGuiWithWeatherInfo: weather ];
                        });
                  });
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                 [ self handleError: error ];
            }];
    });
} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
     [ self handleError: error ];
}];
```



### iAsync approach
Using **iAsync** you can rewrite the code above in functional programming manner. In our example we use a waterfall flow that ensures execution order and passes results of the previous asynchronous function to the one being executed. 

![Waterfall flow](https://github.com/EmbeddedSources/iAsync/raw/readme/readme/2-Waterfall.png)


So, the code above can be rewritten in a declarative manner :

```
+(JFFAsyncOperation)asyncWeatherForAddress:( NSString* )userInput
{
   return bindSequenceOfAsyncOperationsArray
   (
      [ self asyncLocationForAddress: userInput ],
     @[
         [ self parseRawAddressBinder ],
         [ self getWeatherBinder      ],
         [ self parseWeatherBinder    ]
      ]
   );
}
```

And it is as easy to use as built-in dispatch_async() routines :

```
-(IBAction)getWeatherButtonTapped:(id)sender
{
   [ self.txtAddress resignFirstResponder ];
   
   NSString* address = self.txtAddress.text;
   if ( ![ self validateAddress: address ] )
   {
	  // Handle validation error and show alert
      return;
   }
   
   
   JFFAsyncOperation loader = [ AWOperationsFactory asyncWeatherForAddress: address ];
   
   
   __weak ESViewController* weakSelf = self;
   JFFCancelAsyncOperationHandler onCancel = ^void(BOOL isOperationKeepGoing)
   {
      [ weakSelf onWeatherInfoRequestCancelled ];
   };
   JFFDidFinishAsyncOperationHandler onLoaded = ^void(id result, NSError *error)
   {
      [ weakSelf onWeatherInfoLoaded: result
                           withError: error ];
   };
   JFFCancelAsyncOperation cancelLoad = loader( nil, onCancel, onLoaded );
   self->_cancelLoad = cancelLoad;
   
   self.activityIndicator.hidden = NO;
   [ self.activityIndicator startAnimating ];
}

-(IBAction)cancelButtonTapped:(id)sender
{
   if ( nil != self->_cancelLoad )
   {
      self->_cancelLoad( YES );
   }
   
   [ self.activityIndicator stopAnimating ];
   self.activityIndicator.hidden = YES;
   self.resultView.hidden = YES;
}

```


Of course, we should implement download and parsing routines. Full source code of the [sample](https://github.com/dodikk/weather-iasync/blob/master/lib/iAsyncWeatherOperations/iAsyncWeatherOperations/AWOperationsFactory.mm) can be found at the repository below : https://github.com/dodikk/weather-iasync

