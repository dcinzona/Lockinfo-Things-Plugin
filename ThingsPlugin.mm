#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <sqlite3.h>
#import <UIKit/UIKit.h>
#import <UIKit/UIApplication.h>
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBApplication.h>
#include "Plugin.h"

extern "C" CFStringRef UIDateFormatStringForFormatType(CFStringRef type);

#define localize(bundle, str) \
	[bundle localizedStringForKey:str value:str table:nil]

static SBApplication* getApp()
{
	Class cls = objc_getClass("SBApplicationController");
	SBApplicationController* ctr = [cls sharedInstance];

	SBApplication* app = [ctr applicationWithDisplayIdentifier:@"com.culturedcode.ThingsTouch"];
	
	return app;
}

@interface DotView : UIView

@property (nonatomic, retain) UIColor* color;

@end

@implementation DotView

@synthesize color;

-(void) drawRect:(CGRect) rect
{
	CGContextRef ctx = UIGraphicsGetCurrentContext();
	[self.color set];
	CGContextFillEllipseInRect(ctx, rect);

	NSBundle* b = [NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/CalendarUI.framework"];
	NSString* path = [b pathForResource:@"dotshine" ofType:@"png"];
	UIImage* image = [UIImage imageWithContentsOfFile:path];
	[image drawInRect:rect];
}
@end


@interface ThingsView : UIView

@property (nonatomic, retain) DotView* dot;
@property (nonatomic, retain) LILabel* name;
@property (nonatomic, retain) LILabel* due;
@property (nonatomic, retain) UIImageView* priority;

@end

@implementation ThingsView

@synthesize dot, due, name, priority;


static ThingsView* createView(CGRect frame, LITableView* table)
{
	ThingsView* v = [[[ThingsView alloc] initWithFrame:frame] autorelease];
	v.backgroundColor = [UIColor clearColor];

	v.dot = [[[DotView alloc] initWithFrame:CGRectMake(4, 4, 9, 9)] autorelease];
	v.dot.backgroundColor = [UIColor clearColor];
	
	v.name = [table labelWithFrame:CGRectZero];
	v.name.frame = CGRectMake(22, 0, 275, 16);
	v.name.backgroundColor = [UIColor clearColor];

	v.due = [table labelWithFrame:CGRectZero];
	v.due.frame = CGRectMake(22, 16, 275, 14);
	v.due.backgroundColor = [UIColor clearColor];

	v.priority = [[[UIImageView alloc] initWithFrame:CGRectMake(305, 3, 10, 10)] autorelease];
	v.priority.backgroundColor = [UIColor clearColor];

	[v addSubview:v.dot];
	[v addSubview:v.due];
	[v addSubview:v.name];
	[v addSubview:v.priority];

	return v;
}

@end




@interface ThingsViewHeader : UIView

@property (nonatomic, retain) LILabel* name;

@end

@implementation ThingsViewHeader

@synthesize name;

static ThingsViewHeader* createHeaderView(CGRect frame, LITableView* table)
{
	ThingsViewHeader* h = [[[ThingsViewHeader alloc] initWithFrame:frame] autorelease];
	
	NSBundle* b = [NSBundle bundleWithPath:@"/Library/LockInfo/"];
	NSString* path = [b pathForResource:@"section_subheader" ofType:@"png"];
	UIImage* image = [UIImage imageWithContentsOfFile:path];
	h.backgroundColor = [UIColor colorWithPatternImage:image];
	
	h.name = [table labelWithFrame:CGRectZero];
	h.name.frame = CGRectMake(0, 0, 320, 17);
	h.name.backgroundColor = [UIColor clearColor];
	
	[h addSubview:h.name];
	
	return h;
}

@end


@interface ThingsPlugin : NSObject <LIPluginController, LITableViewDelegate, UITableViewDataSource> 
{
	NSTimeInterval lastUpdate;
}

@property (nonatomic, retain) LIPlugin* plugin;
@property (retain) NSDictionary* todoPrefs;
@property (retain) NSArray* todoList;

@property (retain) NSString* sql;
@property (retain) NSString* prefsPath;
@property (retain) NSString* dbPath;

@end

@implementation ThingsPlugin

@synthesize todoList, todoPrefs, sql, plugin, prefsPath, dbPath;



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return self.todoList.count+1;
}

- (UITableViewCell *)tableView:(LITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	NSUInteger row = [indexPath row];

//	NSUInteger countDueTasks=0;
	
//	NSLog(@"LI:Things: countDueTasks %i", countDueTasks);
	
	//NSLog(@"LI:Things: row %i", row);
	
	//NSLog(@"LI:Things: todoList Array %@", self.todoList);
	
	
	
//	NSUInteger rowdict = row;
//	NSDictionary* elem = [self.todoList objectAtIndex:rowdict];
		
//	NSNumber* dateNum = [elem objectForKey:@"due"];
//	if ((dateNum.doubleValue != nil))	{
//		countDueTasks++;
//	}
	
//	NSLog(@"LI:Things: countDueTasks %i", countDueTasks);
		
	int todayRow = 0;
//	int dueRow = countDueTasks+2;
	
	if (row == todayRow) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:nil];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:nil] autorelease];
			ThingsViewHeader* v = createHeaderView(CGRectMake(0, 0, 320, 20), tableView);
			
			v.tag = 56;
			
			[cell.contentView addSubview:v];
		}
		
		ThingsViewHeader* v = [cell.contentView viewWithTag:56];
		
		v.name.style = tableView.theme.summaryStyle;
		v.name.textAlignment = UITextAlignmentCenter;
		
		NSBundle* bundle = [NSBundle bundleForClass:[self class]];
		
		if (row == todayRow)
			v.name.text = localize(bundle, @"Today");
//		if (row == dueRow)
//			v.name.text = localize(bundle, @"Due");
		
		return cell;
	}
		
		
	if (row != todayRow) {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TodoCellToday"];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"TodoCellToday"] autorelease];
			
			
			//Todo: avoid setting negative y-value
			ThingsView* v = createView(CGRectMake(0, 0, 320, 30), tableView);
		
			v.tag = 57;
		
			[cell.contentView addSubview:v];
		}
	
		ThingsView* v = [cell.contentView viewWithTag:57];
	
		v.name.style = tableView.theme.summaryStyle;
		v.due.style = tableView.theme.detailStyle;
	
	
		//NSLog(@"LI:Things: todoList %@", self.todoList);
		
		NSUInteger rowdict = row-1;
		
		NSDictionary* elem = [self.todoList objectAtIndex:rowdict];
		
		v.name.text = [elem objectForKey:@"name"];

		v.dot.hidden = true;
		
	NSNumber* dateNum = [elem objectForKey:@"due"];
	if ((dateNum.doubleValue == nil))	{
		NSBundle* bundle = [NSBundle bundleForClass:[self class]];
		v.due.text = localize(bundle, @"No Due Date");
	}
	else
	{
		UIColor* color;
		NSDate* date = [[[NSDate alloc] initWithTimeIntervalSinceReferenceDate:dateNum.doubleValue] autorelease];
		
		int secondsDifference = (int) [date timeIntervalSinceNow];
		int days = secondsDifference/86400;
				
		NSDateFormatter* df = [[[NSDateFormatter alloc] init] autorelease];
		df.dateFormat = (NSString*)UIDateFormatStringForFormatType(CFSTR("UIWeekdayNoYearDateFormat"));
		
		if (days < 0){
			NSBundle* bundle = [NSBundle bundleForClass:[self class]];
			v.due.text = localize(bundle, @" (%d days overdue)");
			
			NSString *overdueDays = [NSString stringWithFormat: v.due.text, (days*(-1))];
			v.due.text = [[df stringFromDate:date] stringByAppendingString: overdueDays];
			
			color = [UIColor colorWithRed:255
						green:0
						blue:0
						alpha:1];
			v.dot.color = color;
			v.dot.hidden = false;
			[v.dot setNeedsDisplay];			
		}
		else
			color = [UIColor colorWithRed:0
											 green:255
											  blue:0
											 alpha:1];
			v.dot.color = color;
			v.dot.hidden = false;
			[v.dot setNeedsDisplay];
			v.due.text = [df stringFromDate:date];
	}
	
	return cell;
	}
	
}




- (id) initWithPlugin:(LIPlugin*) plugin
{
	self = [super init];
	self.plugin = plugin;
	
	plugin.tableViewDataSource = self;
	plugin.tableViewDelegate = self;

	NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(update:) name:LITimerNotification object:nil];
	[center addObserver:self selector:@selector(update:) name:LIViewReadyNotification object:nil];

	return self;
}

- (void) updateTasks
{
	if (self.dbPath == nil)
	{
		SBApplication* app = getApp();
		NSString* appPath = [app.path stringByDeletingLastPathComponent];
		self.dbPath = [[appPath stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:(@"db.sqlite3")];
		self.prefsPath = [appPath stringByAppendingFormat:@"/Library/Preferences/%@.plist", app.displayIdentifier];
	}

	self.todoPrefs = [NSDictionary dictionaryWithContentsOfFile:self.prefsPath];
	
	//NSLog(@"LI:Things: Prefs: %@: %@", self.prefsPath, self.todoPrefs);
	
	
	//Today tasks Things
	BOOL hideNoDate = true;
	if (NSNumber *n = [self.plugin.preferences valueForKey:@"HideNoDate"]) {
		hideNoDate = n.intValue;
	}
	//NSLog(@"LI:Things: HideNoDate %d", hideNoDate);
	
	NSString *allSql;
	if (hideNoDate) {
		allSql = @"select title,dueDate,createdDate,flagged from Task as t1 where status = 1 and type = 2 and flagged = 1 and dueDate IS NOT NULL";
	}
	else {
		allSql = @"select title,dueDate,createdDate,flagged from Task as t1 where status = 1 and type = 2 and flagged = 1";
	}

	//NSLog(@"LI:Things: allSQL %@", allSql);
	
	
	NSNumber *tasksOrder;
	if (NSNumber *n = [self.plugin.preferences valueForKey:@"tasksOrder"]) {
		tasksOrder = n;
	}
	else {
		tasksOrder = 0;
	}

	
	
	NSString *tasksOrderSql;
	
	switch (tasksOrder.intValue) {
		case 0:
			tasksOrderSql = @"dueDate DESC";
			break;
		case 1:
			tasksOrderSql = @"IFNULL(dueDate, '2030-01-01') ASC";
			break;
		case 2:
			tasksOrderSql = @"IFNULL(dueDate, '2030-01-01') DESC";
			break;
		case 3:
			tasksOrderSql = @"dueDate ASC";
			break;
		default:
			tasksOrderSql = @"dueDate DESC";
			break;
	}
	

	
	//NSLog(@"LI:Things: orderDatedTasks %@", orderDatedTasks);
	NSLog(@"LI:Things: tasksOrder %i", tasksOrder);
	NSLog(@"LI:Things: tasksOrderSql %@", tasksOrderSql);
	
	
	int queryLimit = 5;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"MaxTasks"])
		queryLimit = n.intValue;

	NSString* sql = [NSString stringWithFormat:@"%@ ORDER BY %@, createdDate DESC limit %i;", allSql, tasksOrderSql, queryLimit];
	
	
	NSLog(@"LI:Things: Executing SQL: %@", sql);
			
	/* Get the todo database timestamp */
	//NSFileManager* fm = [NSFileManager defaultManager];
	NSDictionary *dataFileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:self.dbPath traverseLink:YES];
	NSDate* lastDataModified = [dataFileAttributes objectForKey:NSFileModificationDate];
	
	if(![sql isEqualToString:self.sql] || lastUpdate < lastDataModified.timeIntervalSinceReferenceDate)
	{
		NSLog(@"LI:Things: Loading Todo Tasks...");
		self.sql = sql;

		// Update data and read from database
		NSMutableArray *todos = [NSMutableArray arrayWithCapacity:4];
		
		sqlite3 *database = NULL;
		@try
		{		
			if (sqlite3_open([self.dbPath UTF8String], &database) != SQLITE_OK) 
			{
				NSLog(@"LI:Things: Failed to open database.");
				return;
			}

			// Setup the SQL Statement and compile it for faster access
			sqlite3_stmt *compiledStatement = NULL;

			@try
			{
				if (sqlite3_prepare_v2(database, [sql UTF8String], -1, &compiledStatement, NULL) != SQLITE_OK) 
				{
					NSLog(@"LI:Things: Failed to prepare statement: %s", sqlite3_errmsg(database));
					return;
				}
								
				// Loop through the results and add them to the feeds array
				while(sqlite3_step(compiledStatement) == SQLITE_ROW) 
				{
					const char *cText = (const char*)sqlite3_column_text(compiledStatement, 0);
					double cDue  = sqlite3_column_double(compiledStatement, 1);
					double createdDate  = sqlite3_column_double(compiledStatement, 2);
					double flagged  = sqlite3_column_double(compiledStatement, 3);
							
					NSString *aText = [NSString stringWithUTF8String:(cText == NULL ? "" : cText)];
					//NSString *color = (cColor == NULL ? [self.todoPrefs objectForKey:@"UnfiledTaskListColor"] : [NSString stringWithUTF8String:cColor]);
					//NSArray* colorComps = [color componentsSeparatedByString:@":"];
										
					NSDictionary *todoDict = [NSDictionary dictionaryWithObjectsAndKeys:
						aText, @"name",
						[NSNumber numberWithDouble:cDue], @"due",
						[NSNumber numberWithDouble:createdDate], @"createdDate", 
						[NSNumber numberWithDouble:flagged], @"flagged",
						//[NSNumber numberWithDouble:(colorComps.count == 4 ? [[colorComps objectAtIndex:0] doubleValue] : 0)], @"color_r",
						//[NSNumber numberWithDouble:(colorComps.count == 4 ? [[colorComps objectAtIndex:1] doubleValue] : 0)], @"color_g",
						//[NSNumber numberWithDouble:(colorComps.count == 4 ? [[colorComps objectAtIndex:2] doubleValue] : 0)], @"color_b",
						nil];
				
					[todos addObject:todoDict];
				}
			}
			@finally
			{			
				if (compiledStatement != NULL)
					sqlite3_finalize(compiledStatement);
			}
		}
		@finally
		{
			if (database != NULL)
				sqlite3_close(database);
		}
	
		[self performSelectorOnMainThread:@selector(setTodoList:) withObject:todos waitUntilDone:YES];	

		// Inside on SMS and outside on Weather Info.  This is likely location of SB crash
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:1];
		[dict setObject:todos forKey:@"todos"];  
		[[NSNotificationCenter defaultCenter] postNotificationName:LIUpdateViewNotification object:self.plugin userInfo:dict];
		
		lastUpdate = lastDataModified.timeIntervalSinceReferenceDate;
	}
}

- (void) update:(NSNotification*) notif
{
	if (!self.plugin.enabled)
		return;

	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	[self updateTasks];
	[pool release];
}

@end
