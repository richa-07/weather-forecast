//
//  WFWeatherViewController.m
//  WeatherForcast
//  Copyright (c) 2014 Richa Sharma. All rights reserved.

#import "WFWeatherViewController.h"
#import "OWMWeatherAPI.h"
#import "SVProgressHUD.h"
#import <MapKit/MapKit.h>

@interface WFWeatherViewController ()<CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, MKMapViewDelegate> {

    OWMWeatherAPI *_weatherAPI;
    NSArray *_forecast;
    NSDateFormatter *_dateFormatter;
    int downloadCount;
    CLLocationManager *locationManager;
}

@property (weak, nonatomic) IBOutlet UILabel *timeStamp;
@property (weak, nonatomic) IBOutlet UIImageView *weatherTypeImage;
@property (weak, nonatomic) IBOutlet UILabel *weatherTypeLabel;
@property (weak, nonatomic) IBOutlet UILabel *weatherCityName;
@property (weak, nonatomic) IBOutlet UILabel *weatherTemprature;
@property (weak, nonatomic) IBOutlet UITableView *forecastTableView;
@property (weak, nonatomic) IBOutlet UISearchBar *citySearchBar;
@property (strong, nonatomic) IBOutlet NSString *currentCity;
@end

@implementation WFWeatherViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    dispatch_async(dispatch_get_main_queue(), ^(void){
        //Run UI Updates
        [[UIApplication sharedApplication]setNetworkActivityIndicatorVisible:YES];
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        [SVProgressHUD showWithStatus:@"Loading default city.." maskType:SVProgressHUDMaskTypeBlack];
        
    });

    downloadCount = 0;
    [self.forecastTableView setBackgroundColor:[UIColor clearColor]];
    
    NSString *dateComponents = @"H:m yyMMMMd a";
    NSString *dateFormat = [NSDateFormatter dateFormatFromTemplate:dateComponents options:0 locale:[NSLocale systemLocale] ];
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:dateFormat];
    
    _forecast = @[];
    _weatherAPI = [[OWMWeatherAPI alloc] initWithAPIKey:@"1111111111"];
    [_weatherAPI setLangWithPreferedLanguage]; // prefered system language
    [_weatherAPI setTemperatureFormat:kOWMTempCelcius]; // want the temperatures in celcius
    
    // this creates the CCLocationManager that will find your current location
    locationManager = [[CLLocationManager alloc] init];
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
    [locationManager startUpdatingLocation];
    
    [self fetchWeatherDataForSelectedCity:@"Indore"];

}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
    CLGeocoder *geocoder = [[CLGeocoder alloc] init] ;
    [geocoder reverseGeocodeLocation:locationManager.location
                   completionHandler:^(NSArray *placemarks, NSError *error) {
                       NSLog(@"reverseGeocodeLocation:completionHandler: Completion Handler called!");
                       if (error){
                           NSLog(@"Geocode failed with error: %@", error);
                           [self fetchWeatherDataForSelectedCity:@"Indore"];
                           return;
                       }
                       CLPlacemark *placemark = [placemarks objectAtIndex:0];
                       if (![_currentCity isEqualToString:placemark.locality]) {

                           dispatch_async(dispatch_get_main_queue(), ^(void){
                               //Run UI Updates
                               [[UIApplication sharedApplication]setNetworkActivityIndicatorVisible:YES];
                               [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
                               [SVProgressHUD showWithStatus:@"Loading current city.." maskType:SVProgressHUDMaskTypeBlack];
                               
                           });

                           _currentCity = placemark.locality;
                           [self fetchWeatherDataForSelectedCity:placemark.locality];
                       }
                   }];
}

-(void)fetchWeatherDataForSelectedCity:(NSString*)cityName {
    
    downloadCount = 0;
    
    [_weatherAPI currentWeatherByCityName:cityName withCallback:^(NSError *error, NSDictionary *result) {
        if ([result[@"cod"] intValue] == 200) {
            self.weatherCityName.text = [NSString stringWithFormat:@"%@, %@",
                                         result[@"name"],
                                         result[@"sys"][@"country"]
                                         ];
            self.weatherTemprature.text = [NSString stringWithFormat:@"%.1f℃",
                                           [result[@"main"][@"temp"] floatValue] ];
            self.timeStamp.text =  [_dateFormatter stringFromDate:result[@"dt"]];
            self.weatherTypeLabel.text = result[@"weather"][0][@"description"];
            self.weatherTypeImage.image = [UIImage imageNamed:result[@"weather"][0][@"icon"]];
        } else {
            self.weatherCityName.text = @"No City Found";
            self.weatherTemprature.text = @"0.0 C";
            self.timeStamp.text =  [_dateFormatter stringFromDate:[NSDate date]];
            self.weatherTypeLabel.text = @"Unknown";
            self.weatherTypeImage.image = [UIImage imageNamed:result[@"weather"][0][@"icon"]];
            return;
        }
    }];
    
    [_weatherAPI forecastWeatherByCityName:cityName withCallback:^(NSError *error, NSDictionary *result) {
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            //Run UI Updates
            [[UIApplication sharedApplication]setNetworkActivityIndicatorVisible:NO];
            [[UIApplication sharedApplication] endIgnoringInteractionEvents];
            [SVProgressHUD dismiss];
        });
        
        if ([result[@"cod"] intValue] == 200) {
            _forecast = result[@"list"];
            dispatch_async(dispatch_get_main_queue(), ^(void){
                [self.forecastTableView reloadData];
            });
        } else {
            return;
        }
    }];
}

#pragma mark - tableview datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _forecast.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    }
    
    cell.backgroundColor = [UIColor clearColor];
    NSDictionary *forecastData = [_forecast objectAtIndex:indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%.1f/%.1f℃       %@",
                           [forecastData[@"main"][@"temp_max"] floatValue], [forecastData[@"main"][@"temp_min"] floatValue], forecastData[@"weather"][0][@"main"]];
    cell.imageView.image = [UIImage imageNamed:forecastData[@"weather"][0][@"icon"]];
    cell.detailTextLabel.text = [_dateFormatter stringFromDate:forecastData[@"dt"]];
    
    return cell;
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterArrayWithSearchTextWithsearchBar:searchBar andSearchText:searchText];
}

-(void)filterArrayWithSearchTextWithsearchBar:(UISearchBar *)searchBar andSearchText:(NSString*)searchText {
    
    searchText = [searchText stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
    // Filter the array using NSPredicate
    [self fetchWeatherDataForSelectedCity:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self.citySearchBar resignFirstResponder];
    [self.view endEditing:YES];
}

@end
