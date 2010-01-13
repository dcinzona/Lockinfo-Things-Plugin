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

#define allTrim( object ) [object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet] ]

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
@property (retain) NSArray* todoListToday;
@property (retain) NSArray* todoListDue;
@property (retain) NSArray* todoListNext;

@property (retain) NSString* sql;
@property (retain) NSString* prefsPath;
@property (retain) NSString* dbPath;

@end

@implementation ThingsPlugin

@synthesize todoListToday, todoListDue, todoListNext, todoPrefs, sql, plugin, prefsPath, dbPath;



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	int todoListCount = (self.todoListToday.count + self.todoListDue.count + self.todoListNext.count);
	
	if (self.todoListToday.count > 0) {
		//self.showTodoListToday == true;
		todoListCount = todoListCount+1;
	}
	
	if (self.todoListDue.count > 0) {
		//self.showTodoListDue == true;
		todoListCount = todoListCount+1;
	}
	
	if (self.todoListNext.count > 0) {
		//self.showTodoListNext == true;
		todoListCount = todoListCount+1;
	}
	
	NSLog(@"LI:Things: todoListCount: %i", todoListCount);
		
	return todoListCount;
}

- (CGFloat)tableView:(LITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	int row = [indexPath row];
	int todayRow, dueRow, nextRow;
	BOOL showTodoListToday = false, showTodoListDue = false, showTodoListNext = false;
	
	NSLog(@"LI:Things: todoList-Counts: Today: %i Due: %i Next: %i", self.todoListToday.count, self.todoListDue.count, self.todoListNext.count);
	
	if (self.todoListToday.count > 0)
		showTodoListToday = true;
	
	if (self.todoListDue.count > 0)
		showTodoListDue = true;
	
	if (self.todoListNext.count > 0)
		showTodoListNext = true;
	
	//Determine which subsection to show
	
	if (self.todoListToday.count > 0)
		showTodoListToday = true;
	
	if (self.todoListDue.count > 0)
		showTodoListDue = true;
	
	if (self.todoListNext.count > 0)
		showTodoListNext = true;
	
	
	//Determine which subsection to show
	
	if (showTodoListToday == false) {
		todayRow = -1;
	}
	else {
		todayRow = 0;
	}
	
	if (showTodoListDue == false) {
		dueRow = todayRow + self.todoListToday.count;
	}
	else {
		dueRow =  todayRow+self.todoListToday.count+1;
	}
	
	if (showTodoListNext == false) {
		nextRow = -1;
	}
	else {
		nextRow = dueRow+self.todoListDue.count+1;
	}


	if ( (row == todayRow && showTodoListToday == true) ||  (row == dueRow && showTodoListDue == true) || (row == nextRow && showTodoListNext == true) ) {
		return 20;	
	}
	else {
		return 35;
	}

}

- (UITableViewCell *)tableView:(LITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	int row = [indexPath row];
	int todayRow, dueRow, nextRow;
	BOOL showTodoListToday = false, showTodoListDue = false, showTodoListNext = false;
	
	if (self.todoListToday.count > 0)
		showTodoListToday = true;
	
	if (self.todoListDue.count > 0)
		showTodoListDue = true;
	
	if (self.todoListNext.count > 0)
		showTodoListNext = true;
	
	//Determine which subsection to show
	
	if (showTodoListToday == false) {
		todayRow = -1;
	}
	else {
		todayRow = 0;
	}
	
	if (showTodoListDue == false) {
		dueRow = todayRow + self.todoListToday.count;
	}
	else {
		dueRow =  todayRow+self.todoListToday.count+1;
	}
	
	if (showTodoListNext == false) {
		nextRow = -1;
	}
	else {
		nextRow = dueRow+self.todoListDue.count+1;
	}	
	
	
	NSLog(@"LI:Things: subsection rows: Today: %i Due: %i Next: %i", todayRow, dueRow, nextRow);
	
	
	//Subsection Headers
	if ( (row == todayRow && showTodoListToday == true) || 
		 (row == dueRow && showTodoListDue == true) || 
		 (row == nextRow && showTodoListNext == true) 
	   ) {
		
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
		
		//Localize Subsection-Header Text
		NSBundle* bundle = [NSBundle bundleForClass:[self class]];
		
		if (row == todayRow && showTodoListToday == true)
			v.name.text = localize(bundle, @"Today");
		
		if (row == dueRow && showTodoListDue == true)
			v.name.text = localize(bundle, @"Due");
		
		if (row == nextRow && showTodoListNext == true)
			v.name.text = localize(bundle, @"Next");
		
		return cell;
	}
	
	else {
		UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TodoCell"];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"TodoCell"] autorelease];
			
			ThingsView* v = createView(CGRectMake(0, 0, 320, 30), tableView);
		
			v.tag = 57;
		
			[cell.contentView addSubview:v];
		}
	
		ThingsView* v = [cell.contentView viewWithTag:57];
	
		v.name.style = tableView.theme.summaryStyle;
		v.due.style = tableView.theme.detailStyle;
	
		NSDictionary *elem;
				
		if ( (showTodoListToday == true) && (row > todayRow) && (row <= todayRow + self.todoListToday.count) ) {
			int rowdict = row-1;
			elem = [self.todoListToday objectAtIndex:rowdict];
		}
		
		if ( (showTodoListDue == true) && (row > dueRow) && (row <= dueRow + self.todoListDue.count) ) {
			int rowdict = row-dueRow-1;
			elem = [self.todoListDue objectAtIndex:rowdict];
		}
		
		if ( (showTodoListNext == true) && (row > nextRow ) && (row <= nextRow + self.todoListNext.count) ) {
			int rowdict = row-nextRow-1;
			elem = [self.todoListNext objectAtIndex:rowdict];
		}
		
		v.name.text = [elem objectForKey:@"name"];

		v.dot.hidden = true;
	
		//NSLog(@"LI:Things: project %@", [ [elem objectForKey:@"project"] length]);
		
	NSNumber* dateNum = [elem objectForKey:@"due"];
	NSString *project = [elem objectForKey:@"project"];
	if ((dateNum.doubleValue == 0))	{
		if ( [allTrim( project ) length] == 0 ) {
			NSBundle* bundle = [NSBundle bundleForClass:[self class]];
			v.due.text = localize(bundle, @"No Due Date");
		}
		else {
			v.due.text = [elem objectForKey:@"project"];
		}

	}
	else
	{
		UIColor* color;
		NSDate* date = [[[NSDate alloc] initWithTimeIntervalSinceReferenceDate:dateNum.doubleValue] autorelease];
		NSString *project = [elem objectForKey:@"project"];
		
		int secondsDifference = (int) [date timeIntervalSinceNow];
		int days = secondsDifference/86400;
				
		NSDateFormatter* df = [[[NSDateFormatter alloc] init] autorelease];
		df.dateFormat = (NSString*)UIDateFormatStringForFormatType(CFSTR("UIWeekdayNoYearDateFormat"));
		
		if (days < 0){
			
			
			NSBundle* bundle = [NSBundle bundleForClass:[self class]];
			NSString *overdue = localize(bundle, @" (%d days overdue)");
			
			v.due.text = [project stringByAppendingString: overdue];
						
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
			NSString *dueDate = [df stringFromDate:date];
			if (([allTrim( project ) length] == 0 ) == false) {
				v.due.text = [project stringByAppendingString: @": "];
				v.due.text = [v.due.text stringByAppendingString: dueDate];
			}
			else {
				v.due.text = dueDate;
			}

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
	
	
	//Construct WHERE statement based on Plugin-Preferences
	
	//Next tasks Things
	BOOL showNext = true;
	if (NSNumber *n = [self.plugin.preferences valueForKey:@"ShowNext"]) {
		showNext = n.intValue;
	}
		
	NSString *showNextTasks;
	if (showNext == false) {
		showNextTasks = @"AND (todos.flagged = 1 OR todos.dueDate IS NOT NULL)";
	}
	else {
		showNextTasks = @"";
	}

	NSLog(@"LI:Things: showNextTasks %@", showNextTasks);
	
	//Today tasks Things
	BOOL showDue = true;
	if (NSNumber *n = [self.plugin.preferences valueForKey:@"ShowDue"]) {
		showDue = n.intValue;
	}
	
	NSString *showDueTasks;
	if (showDue == true) {
		showDueTasks = @"AND todos.dueDate IS NOT NULL";
	}
	else {
		showDueTasks = @"";
	}

	NSLog(@"LI:Things: showDueTasks %@", showDueTasks);
	
	//Construct first part of SQL statement (SELECT, WHERE)
	NSString* allSql = [NSString stringWithFormat:@"SELECT todos.title as todotitle,todos.dueDate,todos.createdDate,todos.flagged, projects.title as projecttitle FROM Task as todos LEFT OUTER JOIN  Task as projects ON projects.uuid = todos.project WHERE todos.status = 1 AND todos.type = 2 AND todos.focus != '16' %@ %@", showNextTasks, showDueTasks];
	
	//allSql = @"select title,dueDate,createdDate,flagged from Task as t1 where status = 1 and type = 2 and flagged = 1";
	
	//NSLog(@"LI:Things: allSQL %@", allSql);
	
	
	//Contruct ORDER BY statement based on Plugin-Preferences
	
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
			tasksOrderSql = @"todos.dueDate DESC";
			break;
		case 1:
			tasksOrderSql = @"IFNULL(todos.dueDate, '2030-01-01') ASC";
			break;
		case 2:
			tasksOrderSql = @"IFNULL(todos.dueDate, '2030-01-01') DESC";
			break;
		case 3:
			tasksOrderSql = @"todos.dueDate ASC";
			break;
		default:
			tasksOrderSql = @"todos.dueDate DESC";
			break;
	}
	

	
	//NSLog(@"LI:Things: orderDatedTasks %@", orderDatedTasks);
	NSLog(@"LI:Things: tasksOrder %i", tasksOrder);
	NSLog(@"LI:Things: tasksOrderSql %@", tasksOrderSql);
	
	
	int queryLimit = 5;
	if (NSNumber* n = [self.plugin.preferences valueForKey:@"MaxTasks"])
		queryLimit = n.intValue;

	NSString* sql = [NSString stringWithFormat:@"%@ ORDER BY %@, todos.createdDate DESC limit %i;", allSql, tasksOrderSql, queryLimit];
	
	
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
		NSMutableArray *todosDue = [NSMutableArray arrayWithCapacity:5];
		NSMutableArray *todosToday = [NSMutableArray arrayWithCapacity:5];
		NSMutableArray *todosNext = [NSMutableArray arrayWithCapacity:5];
		
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
					const char *cProject  = (const char*)sqlite3_column_text(compiledStatement, 4);
							
					NSString *aText = [NSString stringWithUTF8String:(cText == NULL ? "" : cText)];
					NSString *aProject = [NSString stringWithUTF8String:(cProject == NULL ? "" : cProject)];
					//NSString *color = (cColor == NULL ? [self.todoPrefs objectForKey:@"UnfiledTaskListColor"] : [NSString stringWithUTF8String:cColor]);
					//NSArray* colorComps = [color componentsSeparatedByString:@":"];
										
					NSDictionary *todoDict = [NSDictionary dictionaryWithObjectsAndKeys:
						aText, @"name",
						[NSNumber numberWithDouble:cDue], @"due",
						[NSNumber numberWithDouble:createdDate], @"createdDate", 
						[NSNumber numberWithDouble:flagged], @"flagged", 
						aProject, @"project",
						nil];
				
					if (flagged == 1)
						[todosToday addObject:todoDict];
					if (cDue != 0)
						[todosDue addObject:todoDict];
					if (flagged != 1 && cDue == 0)
						[todosNext addObject:todoDict];
					
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
	
		[self performSelectorOnMainThread:@selector(setTodoListToday:) withObject:todosToday waitUntilDone:YES];	
		[self performSelectorOnMainThread:@selector(setTodoListDue:) withObject:todosDue waitUntilDone:YES];
		[self performSelectorOnMainThread:@selector(setTodoListNext:) withObject:todosNext waitUntilDone:YES];

		// Inside on SMS and outside on Weather Info.  This is likely location of SB crash
		
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithCapacity:3];
		[dict setObject:todosToday forKey:@"todosToday"];  
		[dict setObject:todosDue forKey:@"todosDue"];
		[dict setObject:todosNext forKey:@"todosNext"];
		
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
