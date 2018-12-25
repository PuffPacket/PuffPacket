/*
 Copyright (c) 2013 OpenSourceRF.com.  All right reserved.
 
 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.
 
 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 See the GNU Lesser General Public License for more details.
 
 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free Software
 Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#import <QuartzCore/QuartzCore.h>

#import "AppViewController.h"
@interface AppViewController()
@end

@implementation AppViewController

@synthesize rfduino;
@synthesize longitude;
@synthesize latitude;
@synthesize currentLocation;

+ (void)load
{
    // customUUID = @"c97433f0-be8f-4dc8-b6f0-5343e6100eb4";
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        UIButton *backButton = [UIButton buttonWithType:101];  // left-pointing shape
        [backButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        [backButton addTarget:self action:@selector(disconnect:) forControlEvents:UIControlEventTouchUpInside];
        
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:backButton];
        [[self navigationItem] setLeftBarButtonItem:backItem];
        
        [[self navigationItem] setTitle:@"PuffPacket: RfDuino"];
    }
    puffs = 0;
    ax = 0;
    ay = 0;
    az = 0;
    fileName = @"test2";
    NSString *name = [self getFileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath: name])
    {
        [fileManager createFileAtPath:name contents:nil attributes:nil];
    }
    //create content - four lines of text
//    NSString *content = @"TimeStamp, number of puffs, Duration of puff, latitude, longtude, altitude, speed, activity, accel x, accel y, accel z\n";
//    //save content to the documents directory
//    [content writeToFile:name
//              atomically:NO
//                encoding:NSUTF8StringEncoding
//                   error:nil];
//
    return self;

}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
 
    [rfduino setDelegate:self];
    
    UIColor *start = [UIColor colorWithRed:58/255.0 green:108/255.0 blue:183/255.0 alpha:0.15];
    UIColor *stop = [UIColor colorWithRed:58/255.0 green:108/255.0 blue:183/255.0 alpha:0.45];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = [self.view bounds];
    gradient.colors = [NSArray arrayWithObjects:(id)start.CGColor, (id)stop.CGColor, nil];
    [self.view.layer insertSublayer:gradient atIndex:0];
    
    //location manager properties
    locationManager = [[CLLocationManager alloc]init]; // initializing locationManager
    locationManager.delegate = self; // we set the delegate of locationManager to self.
    locationManager.desiredAccuracy = kCLLocationAccuracyBest; // setting the accuracy
    if ([locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [locationManager requestWhenInUseAuthorization];
    }
    if ([locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [locationManager requestAlwaysAuthorization];
    }

    [locationManager startUpdatingLocation];  //requesting location updates
    ///accel
    self.motionManager = [[CMMotionManager alloc] init];
    [self.motionManager setAccelerometerUpdateInterval:1.0];
    if (_motionManager.accelerometerAvailable) {
        [self.motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue]
                                                 withHandler:^(CMAccelerometerData  *accelerometerData, NSError *error) {
                                                     [self captureAccelertionData:accelerometerData.acceleration];
                                                     if(error){
                                                         NSLog(@"%@", error);
                                                     }
                                                 }];
    }
    if ([CMMotionActivityManager isActivityAvailable]) {
        self.activityManager = [[CMMotionActivityManager alloc] init];
        [self.activityManager startActivityUpdatesToQueue:[[NSOperationQueue alloc] init]
                                              withHandler:
         ^(CMMotionActivity *activity) {
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 if ([activity stationary]) {
                     self->actvy = @"Stationary";
                 }
                 else if ([activity walking]) {
                     self->actvy = @"Walking";
                 }
                 else if ([activity running]) {
                     self->actvy = @"Running";
                 }
                 else if ([activity automotive]) {
                     self->actvy = @"Vehicle";
                 }
                 else if ([activity cycling]) {
                     self->actvy = @"Cycling";
                 }
                 else {
                     self->actvy = @"Unknown";
                 }
             });
         }];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)disconnect:(id)sender
{
    NSLog(@"disconnect pressed");

    [rfduino disconnect];
}

- (void)Send:(NSData *)data
{
    
}

NSString* information = @"";
NSString* lat = @"";
NSString* lon = @"";
NSString* sp = @"";
NSString* alt = @"";

- (void)didReceive:(NSData *)data
{
//    NSLog(@"RecievedRX");
//
//    uint8_t *d = (uint8_t*)[data bytes];
//    NSUInteger len = [data length];
    
    puffs+=1;
    NSInteger duration = dataInt(data);
    
//    NSLog(@"data=%s, length=%.2ld", d, (long)len);
//    NSLog(@"p=%.2ld, d=%.2ld", (long)puffs, (long)duration);
    
    NSString* string1 = [NSString stringWithFormat:@"%li puffs ", (long)puffs];
    NSString* string2 = [NSString stringWithFormat:@"%li ms ", (long)duration];
    
    [label1 setText:string1];
    [label2 setText:string2];
    
    NSDate * now = [NSDate date];
    NSDateFormatter *outputFormatter = [[NSDateFormatter alloc] init];
    [outputFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *newDateString = [outputFormatter stringFromDate:now];
    //[outputFormatter release];
    
    [date setText:newDateString];
    

    
    self.accX.text = [NSString stringWithFormat:@"X: %.4f",ax];
    self.accY.text = [NSString stringWithFormat:@"Y: %.4f",ay];
    self.accZ.text = [NSString stringWithFormat:@"Z: %.4f",az];
    
    accelX = [NSString stringWithFormat:@"X: %.4f",ax];
    accelY = [NSString stringWithFormat:@"Y: %.4f",ay];
    accelZ = [NSString stringWithFormat:@"Z: %.4f",az];
    //request location
    [locationManager requestAlwaysAuthorization];
    [locationManager startUpdatingLocation];
    [locationManager requestLocation];
//    [locationManager stopUpdatingLocation];
    [act setText: [NSString stringWithFormat:@"Activity: %@", actvy]];
    
    [latitude_label setText: [NSString stringWithFormat:@"Latitude: %@", lat]];
    [longitude_label setText:[NSString stringWithFormat:@"Longitude: %@", lon]];
    [altitude_label setText:[NSString stringWithFormat:@"Altitude: %@ meters", alt]];
    [speed setText:[NSString stringWithFormat:@"Speed: %@ m/s", sp]];
    //Data format
    //TimeStamp, number of puffs, Duration of puff, latitude, longtude, altitude, speed, activity, accel x, accel y, accel z
    //concated string
    information = [NSString stringWithFormat: @"%@,%@,%@,%@,%@,%@,%@,%@,%@,%@,%@\n",
                   newDateString, string1, string2, lat, lon, alt, sp, actvy, accelX, accelY, accelZ];
    NSLog(@"%@", information);
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents directory
    documentsDirectory =[documentsDirectory stringByAppendingPathComponent:fileName];
    
    NSError *error;
    
    NSString* contents = [NSString stringWithContentsOfFile:documentsDirectory
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
    if(error) { // If error object was instantiated, handle it.
        [information writeToFile:documentsDirectory
                      atomically:YES encoding:NSUTF8StringEncoding error:&error];
        NSLog(@"ERROR while loading from file: %@", error);
        // …
    }
    contents = [contents stringByAppendingString:information];
    
    [contents writeToFile:documentsDirectory atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:&error];
}
-(void)captureAccelertionData:(CMAcceleration)acceleration{
    ax = acceleration.x;
    ay = acceleration.y;
    az = acceleration.z;
//    NSLog(@"%@",[NSString stringWithFormat:@"X: %.4f",ax]);;
}
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    UIAlertView *errorAlert = [[UIAlertView alloc]initWithTitle:@"Error" message:@"There was an error retrieving your location" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
    [errorAlert show];
    NSLog(@"Error: %@",error.description);
}

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
//    NSLog(@"we are here");
    CLLocation *crnLoc = [locations lastObject];
    lat = [NSString stringWithFormat:@"%.8f",crnLoc.coordinate.latitude];
    lon = [NSString stringWithFormat:@"%.8f",crnLoc.coordinate.longitude];
    alt = [NSString stringWithFormat:@"%.0f",crnLoc.altitude];
    sp = [NSString stringWithFormat:@"%.1f", crnLoc.speed];
    
    //NSLog(@"%@", [locations lastObject]);
}

- (IBAction)uploadData:(id)sender {
    
    NSString* fName =[self getFileName];
    NSURL *url = [NSURL fileURLWithPath:fName];
    NSArray *fileToShare = @[url];
    UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:fileToShare applicationActivities:nil];
    
    NSArray *excludedActivities = @[UIActivityTypePostToTwitter, UIActivityTypePostToFacebook,
                                    UIActivityTypePostToWeibo,
                                    UIActivityTypeMessage, UIActivityTypeMail,
                                    UIActivityTypePrint, UIActivityTypeCopyToPasteboard,
                                    UIActivityTypeAssignToContact, UIActivityTypeSaveToCameraRoll,
                                    UIActivityTypeAddToReadingList, UIActivityTypePostToFlickr,
                                    UIActivityTypePostToVimeo, UIActivityTypePostToTencentWeibo];
    controller.excludedActivityTypes = excludedActivities;
    
    
    [self presentViewController:controller animated:YES completion:nil];
}

- (IBAction)deleteFile:(id)sender {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    NSString *filePath = [documentsPath stringByAppendingPathComponent:fileName];
    
//    BOOL success = [fileManager removeItemAtPath:filePath error:&error];
    
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Delete File"
                                                                   message:@"You are about to delete your data, do you want to continue?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
        
    UIAlertAction *deleteAction = [UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        NSError *error;
        BOOL success = [fileManager removeItemAtPath:filePath error:&error];
    
        if(success){
            UIAlertController* successAlert = [UIAlertController alertControllerWithTitle:@"Success"
                                                                                  message:@"Data Deleted"
                                                                           preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK"
                                                                    style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {}];
            
            [successAlert addAction:defaultAction];
            [self presentViewController:successAlert animated:YES completion:nil];
            NSLog(@"file deleted -:%@ ",[error localizedDescription]);
            NSString *name = [self getFileName];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager createFileAtPath:name contents:nil attributes:nil];
            
        }else{
            UIAlertController* errorAlert = [UIAlertController alertControllerWithTitle:@"Error"
                                                                                message:@"Could not delete file"
                                                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                                                              handler:^(UIAlertAction * action) {}];
            
            [errorAlert addAction:defaultAction];
            [self presentViewController:errorAlert animated:YES completion:nil];
            NSLog(@"Could not delete file -:%@ ",[error localizedDescription]);
        }
    }];
    [alert addAction:deleteAction];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSLog(@"Don't do anything");
    }];
    [alert addAction:cancelAction];
   
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)getFileName
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
    
}


@end
