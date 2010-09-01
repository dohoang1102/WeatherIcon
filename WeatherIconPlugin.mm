#include "WeatherIconPlugin.h"
#include <UIKit/UIKit.h>
#include <UIKit/UIScreen.h>
#include <substrate.h>

@interface UIScreen (WeatherIcon)

-(CGSize) rotatedScreenSize;

@end

@implementation UIScreen (WeatherIcon)

-(CGSize) rotatedScreenSize
{
	CGRect screen = [self bounds];
        int orientation = [[objc_getClass("SBStatusBarController") sharedStatusBarController] statusBarOrientation];
	return (orientation == 90 || orientation == -90 ? 
		CGSizeMake(screen.size.height, screen.size.width) : screen.size);
}

@end


#define localize(str) \
        [self.plugin.bundle localizedStringForKey:str value:str table:nil]

static NSString* cachePath = @"/User/Library/Caches/com.ashman.LibWeather.cache.plist";

@implementation WIForecastView

@synthesize forecast, theme;

@end

@implementation WIForecastIconView

@synthesize icons;

-(void) setFrame:(CGRect) r
{
	[super setFrame:r];
	[self setNeedsDisplay];
}

-(void) drawRect:(struct CGRect) rect
{
	float screenWidth = [[UIScreen mainScreen] rotatedScreenSize].width;
	int width = ((screenWidth - 10) / 6);
	double scale = 0.66;

	NSBundle* bundle = [NSBundle mainBundle];
	id libweather = [objc_getClass("LibWeatherController") sharedInstance];
	if (NSDictionary* theme = [libweather theme])
	{
		if (NSNumber* n = [theme objectForKey:@"LockInfoImageScale"])
			scale = n.doubleValue;
	}

	for (int i = 0; i < self.forecast.count && i < 6; i++)
	{
		id image = [self.icons objectAtIndex:i];
		if (image != [NSNull null])
		{
			UIImage* realImage = (UIImage*) image;
			CGSize s = realImage.size;
			s.width *= scale;
			s.height *= scale;

			CGRect r = CGRectMake((width * i) + (width / 2) - (s.width / 2), (rect.size.height / 2) - (s.height / 2), s.width, s.height);
			[image drawInRect:r];
		}
	}
}

@end

@implementation WIForecastTempView

@synthesize timestamp, updatedString;

-(void) setFrame:(CGRect) r
{
	[super setFrame:r];
	[self setNeedsDisplay];
}

-(void) drawRect:(struct CGRect) rect
{
	float screenWidth = [[UIScreen mainScreen] rotatedScreenSize].width;
	int width = ((screenWidth - 10) / 6);
	for (int i = 0; i < self.forecast.count && i < 6; i++)
	{
		NSDictionary* day = [self.forecast objectAtIndex:i];

		NSString* str = [NSString stringWithFormat:@"%@\u00B0", [day objectForKey:@"high"]];
        	CGRect r = CGRectMake((width * i) - 5, 1, (width / 2) + 5, self.theme.detailStyle.font.pointSize);
        	[self.theme.detailStyle.shadowColor set];
		[str drawInRect:r withFont:self.theme.detailStyle.font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight];

        	r.origin.y -= 1;
        	[self.theme.summaryStyle.textColor set];
		[str drawInRect:r withFont:self.theme.detailStyle.font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight];

		str = [NSString stringWithFormat:@" %@\u00B0", [day objectForKey:@"low"]];
        	r = CGRectMake((width * i) + r.size.width - 5, 1, (width / 2) + 5, self.theme.detailStyle.font.pointSize);
        	[self.theme.detailStyle.shadowColor set];
		[str drawInRect:r withFont:self.theme.detailStyle.font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentLeft];

        	r.origin.y -= 1;
        	[self.theme.detailStyle.textColor set];
		[str drawInRect:r withFont:self.theme.detailStyle.font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentLeft];
	}

	if (self.timestamp)
	{
		NSDateFormatter* df = [[[NSDateFormatter alloc] init] autorelease];
		df.dateStyle = NSDateFormatterShortStyle;
		df.timeStyle = NSDateFormatterShortStyle;
		NSString* str = [NSString stringWithFormat:@"%@ %@", self.updatedString, [df stringFromDate:[NSDate dateWithTimeIntervalSince1970:self.timestamp.doubleValue]]];

		UIFont* font = [UIFont boldSystemFontOfSize:(self.theme.detailStyle.font.pointSize - 2)];
		CGRect r = CGRectMake(0, self.theme.detailStyle.font.pointSize + 8, screenWidth, font.pointSize);
        	[self.theme.detailStyle.shadowColor set];
		[str drawInRect:r withFont:font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];

        	r.origin.y -= 1;
        	[self.theme.detailStyle.textColor set];
		[str drawInRect:r withFont:font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
	}
}

@end

@implementation WIForecastDaysView

-(void) setFrame:(CGRect) r
{
	[super setFrame:r];
	[self setNeedsDisplay];
}

-(void) drawRect:(struct CGRect) rect
{
        NSDateFormatter* df = [[[NSDateFormatter alloc] init] autorelease];
        NSArray* weekdays = df.shortStandaloneWeekdaySymbols;

	float screenWidth = [[UIScreen mainScreen] rotatedScreenSize].width;
	int width = ((screenWidth - 10) / 6);
	for (int i = 0; i < self.forecast.count && i < 6; i++)
	{
		NSDictionary* day = [self.forecast objectAtIndex:i];
		
		NSNumber* daycode = [day objectForKey:@"daycode"];
		NSString* str = [[weekdays objectAtIndex:daycode.intValue] uppercaseString];
        	CGRect r = CGRectMake((width * i), 1, width, self.theme.detailStyle.font.pointSize + 2);
        	[self.theme.detailStyle.shadowColor set];
		[str drawInRect:r withFont:self.theme.detailStyle.font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];

        	r.origin.y -= 1;
        	[self.theme.summaryStyle.textColor set];
		[str drawInRect:r withFont:self.theme.detailStyle.font lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentCenter];
	}
}

@end

extern "C" UIImage *_UIImageWithName(NSString *);

@implementation WeatherIconPlugin

@synthesize dataCache, iconCache, plugin, daysView, iconView, tempView, updateLock, reloadCondition;

-(id) loadIcon:(NSString*) path
{
	id icon = [self.iconCache objectForKey:path];

	if (path != nil && icon == nil)
	{
		icon = [UIImage imageWithContentsOfFile:path];
		[self.iconCache setValue:icon forKey:path];
	}

	return icon;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
        return 3;
}

- (NSString *)tableView:(LITableView *)tableView detailForHeaderInSection:(NSInteger)section
{
	BOOL hide = false;
	if (NSNumber* b = [self.plugin.preferences objectForKey:@"HideDescription"])
		hide = b.boolValue;

	if (hide)
		return @"";
	
	NSDictionary* weather = [self.dataCache objectForKey:@"weather"];
	if (NSNumber* code = [weather objectForKey:@"code"])
	{
		if (code.intValue >= 0 && code.intValue < descriptions.count)
		{
			return localize([descriptions objectAtIndex:code.intValue]);
		}
	}

	return localize([weather objectForKey:@"description"]);
}

-(UIImage*) defaultIcon:(NSNumber*) code night:(BOOL) night
{
	if (code)
	{
		NSArray* icons = (night ? defaultNightIcons : defaultIcons);
		if (code.intValue >= 0 && code.intValue < icons.count)
			if (NSString* path = [self.plugin.bundle pathForResource:[icons objectAtIndex:code.intValue] ofType:@"png"])
				return [self loadIcon:path];
	}

	return nil;
}

-(UIImage*) defaultIcon:(NSNumber*) code
{
	return [self defaultIcon:code night:false];
}

-(UIImageView*) weatherIcon
{
	double scale = 0.33;

	NSDictionary* weather = [self.dataCache objectForKey:@"weather"];
	UIImage* icon = [self loadIcon:[weather objectForKey:@"icon"]];
	if (icon == nil)
	{
		BOOL night = false;
		if (NSNumber* b = [weather objectForKey:@"night"])
			night = b.boolValue;

		icon = [self defaultIcon:[weather objectForKey:@"code"] night:night];
		scale = 0.45;
	}

	if (icon)
	{
		id libweather = [objc_getClass("LibWeatherController") sharedInstance];
		if (NSDictionary* theme = [libweather theme])
			if (NSNumber* n = [theme objectForKey:@"StatusBarImageScale"])
				scale = n.doubleValue;

		CGSize s = icon.size;
		s.width = s.width * scale;
		s.height = s.height * scale;

        	UIImageView* view = [[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, s.width, s.height)] autorelease];
		view.image = icon;
		return view;
	}

	return nil;
}

- (UIImageView *)tableView:(LITableView *)tableView iconForHeaderInSection:(NSInteger)section
{
	return [self weatherIcon];
}

- (CGFloat)tableView:(LITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	switch (indexPath.row)
	{
		case 0:
			return tableView.theme.detailStyle.font.pointSize + 6;
		case 1:
			return 30;
		case 2:
			BOOL show = false;
			if (NSNumber* n = [self.plugin.preferences objectForKey:@"ShowUpdateTime"])
				show = n.boolValue;

			float height = tableView.theme.detailStyle.font.pointSize + 6;
			return (show ? 2 * height : height);
	}
}

- (NSString *)tableView:(LITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	NSDictionary* weather = [self.dataCache objectForKey:@"weather"];
	NSString* city = [weather objectForKey:@"city"];
	NSRange r = [city rangeOfString:@","];
	if (r.location != NSNotFound)
		city = [city substringToIndex:r.location];

	return [NSString stringWithFormat:@"%@: %d\u00B0", city, [[weather objectForKey:@"temp"] intValue]];
}

-(void) updateWeatherViews
{
	NSDictionary* weather = [self.dataCache objectForKey:@"weather"];
	NSArray* forecast = [[weather objectForKey:@"forecast"] copy];

	self.daysView.forecast = forecast;
	[self.daysView setNeedsDisplay];

	self.iconView.forecast = forecast;

	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:6];
	for (int i = 0; i < forecast.count && i < 6; i++)
	{
		NSDictionary* day = [forecast objectAtIndex:i];
		UIImage* icon = [self loadIcon:[day objectForKey:@"icon"]];

		if (icon == nil)
			icon = [self defaultIcon:[day objectForKey:@"code"]];

		[arr addObject:(icon == nil ? [NSNull null] : icon)];
	}
	self.iconView.icons = arr;
	[self.iconView setNeedsDisplay];

	BOOL show = false;
	if (NSNumber* n = [self.plugin.preferences objectForKey:@"ShowUpdateTime"])
		show = n.boolValue;

	self.tempView.forecast = forecast;
	self.tempView.updatedString = localize(@"Updated");
	self.tempView.timestamp = (show ? [weather objectForKey:@"timestamp"] : nil);
	[self.tempView setNeedsDisplay];

	[forecast release];
}

- (UITableViewCell *)tableView:(LITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	WIForecastView* fcv = nil;
	switch (indexPath.row)
	{
		case 0:
			fcv = self.daysView;
			break;
		case 1:
			fcv = self.iconView;
			break;
		case 2:
			fcv = self.tempView;
			break;
	}

	int height = [self tableView:tableView heightForRowAtIndexPath:indexPath];
	NSString* reuse = [NSString stringWithFormat:@"Forecast%d", indexPath.row];

	UITableViewCell *fc = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (fc == nil)
	{
		fc = [[[UITableViewCell alloc] initWithFrame:CGRectMake(0, 0, [[UIScreen mainScreen] rotatedScreenSize].width, height) reuseIdentifier:reuse] autorelease];
		fc.backgroundColor = [UIColor clearColor];
	}

	for (UIView* subview in fc.contentView.subviews)
		[subview removeFromSuperview];
	[fc.contentView addSubview:fcv];

	fcv.frame = CGRectMake(10, (indexPath.row == 0 ? 2 : 0), [[UIScreen mainScreen] rotatedScreenSize].width - 10, height);
	fcv.backgroundColor = [UIColor clearColor];
	fcv.theme = tableView.theme;
	fcv.hidden = false;
	fcv.alpha = 1;

	NSDictionary* weather = [self.dataCache objectForKey:@"weather"];
	NSArray* forecast = [[weather objectForKey:@"forecast"] copy];
	fcv.forecast = forecast;

	if (indexPath.row == 1)
	{
		NSMutableArray* arr = [NSMutableArray arrayWithCapacity:6];
		for (int i = 0; i < forecast.count && i < 6; i++)
		{
			NSDictionary* day = [forecast objectAtIndex:i];
			UIImage* icon = [self loadIcon:[day objectForKey:@"icon"]];
	
			if (icon == nil)
				icon = [self defaultIcon:[day objectForKey:@"code"]];
	
			[arr addObject:(icon == nil ? [NSNull null] : icon)];
		}
		self.iconView.icons = arr;
	}

	[forecast release];

	BOOL show = false;
	if (NSNumber* n = [self.plugin.preferences objectForKey:@"ShowUpdateTime"])
		show = n.boolValue;

	self.tempView.updatedString = localize(@"Updated");
	self.tempView.timestamp = (show ? [weather objectForKey:@"timestamp"] : nil);

	// mark dirty
	[fcv setNeedsDisplay];

	return fc;
}

-(id) initWithPlugin:(LIPlugin*) plugin 
{
	self = [super init];
	self.plugin = plugin;
	self.dataCache = [NSMutableDictionary dictionaryWithCapacity:10];
	self.iconCache = [NSMutableDictionary dictionaryWithCapacity:10];

	self.daysView = [[[WIForecastDaysView alloc] init] autorelease];
	self.daysView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.iconView = [[[WIForecastIconView alloc] init] autorelease];
	self.iconView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tempView = [[[WIForecastTempView alloc] init] autorelease];
	self.tempView.autoresizingMask = UIViewAutoresizingFlexibleWidth;

	self.reloadCondition = [[[NSCondition alloc] init] autorelease];
	self.updateLock = [[[NSLock alloc] init] autorelease];

	plugin.tableViewDataSource = self;
	plugin.tableViewDelegate = self;

        NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(update:) name:LIViewReadyNotification object:nil];
        [center addObserver:self selector:@selector(updateOnUpdate:) name:@"LWWeatherUpdatedNotification" object:nil];

	return self;
}

-(void) notifyLockInfo
{
	[self.plugin updateView:self.dataCache];
}

-(void) updateWeather:(NSDictionary*) weather
{
	if (!self.plugin.enabled)
		return;

	if ([self.updateLock tryLock])
	{
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:weather, @"weather", nil];
		[self.dataCache setDictionary:dict];
		[self performSelectorOnMainThread:@selector(updateWeatherViews) withObject:nil waitUntilDone:YES];
		[self notifyLockInfo];
		[self.updateLock unlock];
	}
}

- (NSString *)tableView:(LITableView *)tableView reloadDataInSection:(NSInteger)section
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"LWRefreshNotification" object:nil];
	[self.reloadCondition lock];
	[self.reloadCondition wait];
	[self.reloadCondition unlock];
}

-(void) updateOnUpdate:(NSNotification*) notif
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[self updateWeather:notif.userInfo];
	[self.reloadCondition broadcast];
	[pool release];
}

-(void) update:(NSNotification*) notif
{
	if (!self.plugin.enabled)
		return;

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	if (NSDictionary* current = [NSDictionary dictionaryWithContentsOfFile:cachePath])
	{
//		NSLog(@"LI:Weather: Updating when view is ready");
		[self updateWeather:current];
	}

	[pool release];
}

@end
