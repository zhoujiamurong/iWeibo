//
//  PersonalMsgViewController.m
//  iweibo
//
//  Created by LiQiang on 12-1-29.
//  Copyright 2012年 Beyondsoft. All rights reserved.
//

#import "PersonalMsgViewController.h"
#import "IWeiboAsyncApi.h"
#import "PersonalMsgHeaderView.h"
#import "PersonalMsgModel.h"
#import "CellZeroView.h"
#import "CellOneView.h"
#import "MBProgressHUD.h"
#import "Canstants_Data.h"
#import "ComposeBaseViewController.h"
#import "ComposeViewControllerBuilder.h"
#import "MyAudience.h"
#import "MyListenTo.h"
#import "MessageViewUtility.h"
#import "DetailPageConst.h"
#import "WebUrlViewController.h"
#import "IWBSvrSettingsManager.h"
#import "HpThemeManager.h"
#import "SCAppUtils.h"
@implementation PersonalMsgViewController
@synthesize listMsgView,dataSourceArr,cell0Height,cell0OpenStatus,tempPersonMsgDic,accountName,first,arrawImage,oddEven,pushControllerType;
////////////////
@synthesize infoArray;
@synthesize oldTime, lastid,nNewTime,sinceTime,pushType, reachEnd,aApi;
@synthesize heights;
////////////////////

// 初始化方法
- (id)init {
	self = [super init];
	if (nil != self) {
		reachEnd = NO;
        self.heights = [NSMutableDictionary dictionaryWithCapacity:20];
	}
	
	return self;
}


- (void)dealloc {
    CLog(@"%s", __FUNCTION__);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kThemeDidChangeNotification object:nil];
    [arrawImage release];
    [rightBarBtn release];
    [cellZero release];
    [cellOne release];
    [headerView release];
    [listMsgView release];	
	/////////////
    [aApi cancelSpecifiedRequest];
	[aApi release];
	[MBprogress1 release];
    [heights release];
    
    [super dealloc];
}

- (void) showMBProgress1{
    if (MBprogress1 == nil) {
        MBprogress1 = [[MBProgressHUD alloc] initWithFrame:CGRectMake(30, 80, 260, 200)]; 
    }
    [self.view addSubview:MBprogress];  
    [self.view bringSubviewToFront:MBprogress1];  
    MBprogress1.labelText = @"载入中...";  
    MBprogress1.removeFromSuperViewOnHide = YES;
    [MBprogress1 show:YES];  
}
- (void) hiddenMBProgress1{
    [MBprogress1 hide:YES];
}

- (void)showMBProgress{
    if (MBprogress == nil) {
        MBprogress = [[MBProgressHUD alloc] initWithFrame:CGRectMake(30, 80, 260, 200)]; 
    }
    [self.view addSubview:MBprogress];  
    [self.view bringSubviewToFront:MBprogress];  
    MBprogress.labelText = @"加载中,请稍候";  
	MBprogress.labelFont = [UIFont systemFontOfSize:12];
    MBprogress.removeFromSuperViewOnHide = YES;
    [MBprogress show:YES];  
}
- (void)hiddenMBProgress{
    [MBprogress hide:YES];
}
- (void)showErrorView:(NSString *)errorMsg{
    UIImageView *errorBg = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"error.png"]];
    if (MBprogress != nil) {
        [MBprogress release];
    }
    MBprogress = [[MBProgressHUD alloc] initWithFrame:CGRectMake(30, 80, 260, 200)]; 
    [self.view addSubview:MBprogress];  
    [self.view bringSubviewToFront:MBprogress];  
    MBprogress.labelText = errorMsg;  
    MBprogress.labelFont = [UIFont systemFontOfSize:12];
    MBprogress.removeFromSuperViewOnHide = YES;
    MBprogress.customView = errorBg;
    MBprogress.mode = MBProgressHUDModeCustomView;
    [MBprogress show:YES];  
    [errorBg release];
    [self performSelector:@selector(hiddenMBProgress) withObject:nil afterDelay:0.5];
}

- (void)listenOperateSucc:(NSDictionary *)dic {
    NSLog(@"dict=%@", dic);
    NSString *strDes = (NSString *)[dic objectForKey:@"msg"];
    if ([[dic objectForKey:@"ret"] intValue]!=0) {
        [self showErrorView:@"收听失败"];
		bSendingListenOperRequest = NO;
		//NSLog(@"bSendingListenOperRequest = NO");
        return;
    }
    if ([rightBtn.titleLabel.text isEqualToString:@"取消收听"]) {
        [rightBtn setTitle:@"收听" forState:UIControlStateNormal];
    }else if([rightBtn.titleLabel.text isEqualToString:@"收听"])
    {//收听
        [rightBtn setTitle:@"取消收听" forState:UIControlStateNormal];
    }
    NSMutableString *listenStatusLblText = [personMsg listenStatusChange];
    cellZero.listenStatusLbl.text = listenStatusLblText;
	bSendingListenOperRequest = NO;
	//NSLog(@"bSendingListenOperRequest = NO");
}
- (void)listenOperateFail:(NSError *)error {
    [self showErrorView:@"加载失败"];
	bSendingListenOperRequest = NO;
}

#pragma mark - View lifecycle

- (void)backAction:(id)sender {
    [aApi cancelCurrentRequest];
	
	// 将用户的收听状态传递给热门用户界面，如果改界面存在的话
	for(id controller in self.navigationController.viewControllers) {
		if ([controller isKindOfClass:[HotUserViewController class]]) {
			for(HotUserInfo *user in ((HotUserViewController *)controller).entries) {
				if ([user.userName isEqualToString:self.accountName]) {
					if ([rightBtn.titleLabel.text isEqualToString:@"收听"]) {
						user.hasListen = @"0";
					}else {
						user.hasListen = @"1";
					}
				}
			}
			break;
		}
	}
	
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)rightBtnAction {
    CLog(@"dianjile");
    NSMutableDictionary *paramters = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                               @"json",@"format",
                               self.accountName,@"name"
                               , nil];
    NSLog(@"self.accountName=%@", self.accountName);
    if ([rightBtn.titleLabel.text isEqualToString:@"取消收听"] && !bSendingListenOperRequest) {
       //取消收听 
		//NSLog(@"bSendingListenOperRequest = YES");
		bSendingListenOperRequest = YES;
        [paramters setObject:URL_FRIENDS_DEL forKey:@"request_api"];
        [aApi friendsDelWithParamters:paramters delegate:self onSuccess:@selector(listenOperateSucc:)  onFailure:@selector(listenOperateFail:)];
    }
    else if([rightBtn.titleLabel.text isEqualToString:@"收听"] && !bSendingListenOperRequest) {//收听
		bSendingListenOperRequest = YES;
		//NSLog(@"bSendingListenOperRequest = YES");
        [paramters setObject:URL_FRIENDS_ADD forKey:@"request_api"];
        [aApi friendsAddWithParamters:paramters delegate:self onSuccess:@selector(listenOperateSucc:)  onFailure:@selector(listenOperateFail:)];
    }
}
- (void)talkBtnClickedAction{
    NSMutableString *talkTitle = [NSMutableString stringWithString:@"对 "];
    [talkTitle appendString:[self.tempPersonMsgDic objectForKey:@"nick"]];
    [talkTitle appendString:@" 说"];
    NSMutableString *talkText = [NSMutableString stringWithString:@"@"];
    [talkText appendString:self.accountName];
    Draft *draft = [[Draft alloc] init];
	draft.draftType = BROADCAST_MESSAGE; 
	draft.draftTitle = talkTitle;
	draft.draftText = talkText;	
	ComposeBaseViewController	*composeViewController =  [ComposeViewControllerBuilder createWithDraft:draft];
	[draft release];
	UINavigationController		*composeNavController = [[[UINavigationController alloc] initWithRootViewController:composeViewController] autorelease];
    [self presentModalViewController:composeNavController animated:YES];
	// composeViewController无需手动释放
	//[ComposeViewControllerBuilder desposeViewController:composeViewController];

}

- (void)updateTheme:(NSNotificationCenter *)noti{
    NSDictionary *plistDict = [[HpThemeManager sharedThemeManager]themeDictionary];
    NSString *themePathTmp = [plistDict objectForKey:@"Common"];
	NSString *themePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:themePathTmp];
    [rightBtn setBackgroundImage:[UIImage imageWithContentsOfFile:[themePath stringByAppendingPathComponent:@"CancelListen.png"]] forState:UIControlStateNormal];
}

- (void)addTitleAndRightBarBtn {
    NSDictionary *plistDict = nil;
    NSDictionary *pathDic = [[NSUserDefaults standardUserDefaults]objectForKey:@"ThemePath"];
    if ([pathDic count] == 0){
        NSString *skinPath = [[NSBundle mainBundle] pathForResource:@"ThemeManager" ofType:@"plist"];
        plistDict = [[NSArray arrayWithContentsOfFile:skinPath] objectAtIndex:0]; 
    }
    else{
        plistDict = pathDic;
    }
    
	NSString *themePathTmp = [plistDict objectForKey:@"Common"];
	NSString *themePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:themePathTmp];
    
	self.title = [self.tempPersonMsgDic objectForKey:@"nick"];
    //self.navigationItem.title = [self.tempPersonMsgDic objectForKey:@"nick"];
    if (rightBtn==nil) {
        rightBtn = [UIButton buttonWithType:UIButtonTypeCustom];
	 [rightBtn setBackgroundImage:[UIImage imageWithContentsOfFile:[themePath stringByAppendingPathComponent:@"CancelListen.png"]] forState:UIControlStateNormal];
        [rightBtn addTarget:self action:@selector(rightBtnAction) forControlEvents:UIControlEventTouchUpInside];
        rightBtn.frame =  CGRectMake(280, 0, 55, 30);
        rightBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    }
    [rightBtn setTitle:@"收听" forState:UIControlStateNormal];
    if (rightBarBtn==nil) {
        rightBarBtn = [[UIBarButtonItem alloc] initWithCustomView:rightBtn];
        self.navigationItem.rightBarButtonItem = rightBarBtn;
    }
    if (personMsg.listenStatusInfo==10 || personMsg.listenStatusInfo==11) {
        [rightBtn setTitle:@"取消收听" forState:UIControlStateNormal];
    }
    if (personMsg.listenStatusInfo == 120) {
        rightBtn.enabled = NO;
    }else {
        rightBtn.enabled = YES;
    }
    CLog(@"self.accountName == %@",self.accountName);
 	NSString *loginUserName = [IWBSvrSettingsManager sharedSvrSettingManager].activeSite.loginUserName;
    CLog(@"当前用户账户：==%@",loginUserName);
   if ([self.accountName isEqualToString:loginUserName]) {
        rightBtn.hidden = YES;
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateTheme:) name:kThemeDidChangeNotification object:nil];
    
}
- (void)tableViewDataSource {
    personMsg = [PersonalMsgModel sharePersonMsg];
    self.dataSourceArr = [personMsg getDataSourceMsg:self.tempPersonMsgDic];
    self.first=1;
}
- (void)addArrawImage
{
    NSDictionary *cell0DicMsg = [self.dataSourceArr objectAtIndex:0];
    if (cell0DicMsg!=NULL) {
        if ([[cell0DicMsg allKeys] containsObject:KMSGPART2] || [[cell0DicMsg allKeys] containsObject:KIDENTIFY]) {
            arrawImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"down.png"]];
            arrawImage.frame = CGRectMake(300, 137, 10, 7);
            [self.listMsgView addSubview:arrawImage];
        }
    }
}
- (void)changeHeaderViewData
{
    NSString *strHead = [self.tempPersonMsgDic objectForKey:@"head"];
    if (nil == strHead) {
        strHead = @"";
    }
    NSMutableString *headUrl = [NSMutableString stringWithString:strHead];
	[headUrl appendString:@"/180"];
    headerView.urlString = headUrl;
    [headerView getData];
    self.oddEven = -1;
    [self addArrawImage];
}

- (void)fanlistSuc:(NSDictionary *)dic {
	NSLog(@"fanlist:%@", dic);
}

- (void)idollistSuc:(NSDictionary *)dic {
	NSLog(@"idolList:%@", dic);
}

- (void)listenerBtnAction {
    CLog(@"点击听众");
	/*
	NSMutableDictionary *paramters = [[NSMutableDictionary alloc] initWithCapacity:10];
	[paramters setValue:@"json" forKey:@"format"];
	[paramters setValue:@"10" forKey:@"reqnum"];
	[paramters setValue:0 forKey:@"startindex"];
	[paramters setValue:self.accountName forKey:@"name"];
	[paramters setValue:URL_USER_FANLIST forKey:@"request_api"];
	
	IWeiboAsyncApi *apis = [[IWeiboAsyncApi alloc] init];
	[apis getUserFanListWithParamters:paramters
							 delegate:self
							onSuccess:@selector(fanlistSuc:)
							onFailure:nil];
	 */
	MyAudience *audience = [[MyAudience alloc] initWithName:self.accountName];
	audience.audNum = [[self.dataSourceArr objectAtIndex:1] objectForKey:KNUMLISTENER];
	audience.controllerType = self.pushControllerType;
	[self.navigationController pushViewController:audience animated:YES];
    [audience release];
}
- (void)listenToBtnAction {
    CLog(@"点击收听");
	/*
	NSMutableDictionary *paramters = [[NSMutableDictionary alloc] initWithCapacity:10];
	[paramters setValue:@"json" forKey:@"format"];
	[paramters setValue:@"10" forKey:@"reqnum"];
	[paramters setValue:0 forKey:@"startindex"];
	[paramters setValue:self.accountName forKey:@"name"];
	[paramters setValue:URL_USER_IDOLLIST forKey:@"request_api"];
	
	IWeiboAsyncApi *apis = [[IWeiboAsyncApi alloc] init];
	[apis getUserIdolListWithParamters:paramters
							 delegate:self
							 onSuccess:@selector(idollistSuc:)
							onFailure:nil];
    */
	MyListenTo *listen = [[MyListenTo alloc] initWithName:self.accountName];
	NSLog(@"self.dataSourceArr:%@",self.dataSourceArr);
	listen.lisNum = [[self.dataSourceArr objectAtIndex:1] objectForKey:KNUMLISTENTO];
	listen.controllerType = self.pushControllerType;
	[self.navigationController pushViewController:listen animated:YES];
	[listen release];
}
- (void)palyRotation
{
//    static int flag = 1;
    if (arrawImage!=NULL) {
        [UIImageView beginAnimations:nil context:nil];
        [UIImageView setAnimationDuration:0.1];
        //CGAffineTransform begin = CGAffineTransformIdentity;
        arrawImage.transform = CGAffineTransformMakeRotation(M_PI*self.oddEven);
        [UIImageView commitAnimations];
        if (self.oddEven ==-1) {
            self.oddEven = 0;
        }else
        {
            self.oddEven =-1;
        }

    }
}
- (void)moreMsgBtn {
    CLog(@"点击展开更多信息");
    [self palyRotation];
    self.first = 110;
    if (self.cell0OpenStatus == 0) {
        //打开
        self.cell0Height = [[[self.dataSourceArr objectAtIndex:0] objectForKey:KCELL0OPENH] intValue];
        self.cell0OpenStatus = 1;
    }else {
        //关闭
        self.cell0Height = CELL0H;
        self.cell0OpenStatus = 0;
    }
    
   [listMsgView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:0 inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
//    if (self.cell0OpenStatus == 0) {
    [listMsgView reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:0 inSection:0], nil] withRowAnimation:UITableViewRowAnimationNone];
//   }
    CLog(@"cell0height%f",cellZero.frame.size.height);
}
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)addBarBtn {
    NSDictionary *plistDict = nil;
    NSDictionary *pathDic = [[NSUserDefaults standardUserDefaults]objectForKey:@"ThemePath"];
    if ([pathDic count] == 0){
        plistDict = [[HpThemeManager sharedThemeManager]themeDictionary];
        if ([plistDict count] == 0) {
            NSString *skinPath = [[NSBundle mainBundle] pathForResource:@"ThemeManager" ofType:@"plist"];
            plistDict = [[NSArray arrayWithContentsOfFile:skinPath] objectAtIndex:0];
        }
    }
    else{
        plistDict = pathDic;
    }
	NSString *themePathTmp = [plistDict objectForKey:@"Common"];
	NSString *themePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:themePathTmp];
    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [backBtn setBackgroundImage:[UIImage imageWithContentsOfFile:[themePath stringByAppendingPathComponent:@"hotUserBack.png"]] forState:UIControlStateNormal];
   // [backBtn setBackgroundImage:[UIImage imageNamed:PBACKBTN1] forState:UIControlStateHighlighted];
    [backBtn addTarget:self action:@selector(backAction:) forControlEvents:UIControlEventTouchUpInside];
    backBtn.frame =  CGRectMake(0, 0, 48, 30);
	backBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
    [backBtn setTitle:@"返回" forState:UIControlStateNormal];
    backBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    
	UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:backBtn];
	self.navigationItem.leftBarButtonItem = item;
	[item release];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    CLog(@"个人资料 页面");

	self.lastid = @"0";// 初始值为0
    
    NSDictionary *plistDict = nil;
    NSDictionary *pathDic = [[NSUserDefaults standardUserDefaults]objectForKey:@"ThemePath"];
    if ([pathDic count] == 0){
        NSString *skinPath = [[NSBundle mainBundle] pathForResource:@"ThemeManager" ofType:@"plist"];
        plistDict = [[NSArray arrayWithContentsOfFile:skinPath] objectAtIndex:0]; 
    }
    else{
        plistDict = pathDic;
    }
    
    NSString *themePathTmp = [plistDict objectForKey:@"Common"];
    NSString *themePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:themePathTmp];
    UIImage *navImage = [UIImage imageWithContentsOfFile:[themePath stringByAppendingPathComponent:@"navigationbar_bg.png"]];
    [SCAppUtils navigationController:self.navigationController setImage:navImage];

	UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStyleBordered target:nil action:nil];
	self.navigationItem.backBarButtonItem = item;
	[item release];
	
	[self addBarBtn];

	if (![self.navigationItem.backBarButtonItem.title isEqualToString:@"返回"]) {
		self.navigationItem.backBarButtonItem.title = @"返回";
	}
    
	 aApi = [[IWeiboAsyncApi alloc] init];
	listMsgView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 416) style:UITableViewStylePlain];
	//listMsgView.separatorColor = [UIColor clearColor];
	listMsgView.backgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"personScollBg.png"]] autorelease];
	listMsgView.delegate = self;
	listMsgView.dataSource = self;
	
	self.cell0Height = CELL0H;
	self.cell0OpenStatus = 0;
	[self.view addSubview:listMsgView];
	
	headerView = [[PersonalMsgHeaderView alloc] init];
	headerView.accountName = self.accountName;
	headerView.parentController = self;
	[headerView constructFrame:CGRectMake(0, 0, 320,100)];
	listMsgView.tableHeaderView = headerView;
	
	/////////////////////////////////////////////////
	_reloading = YES;
	// 加载更多
	loadCell = [[LoadCell alloc]initWithFrame:CGRectMake(0, 0, 320, 50)];
	listMsgView.tableFooterView = loadCell;
	
	self.infoArray = [NSMutableArray arrayWithCapacity:100];
	
    [self showMBProgress1];
	self.pushType = @"2";
	[self requstWebService:@"0":@"0":@"0x0":@"0"];
	////////////////////////////////////////////////////
    NSDictionary *requestDic = [NSDictionary dictionaryWithObjectsAndKeys:
                                URL_OTHER_INFO,@"request_api",
                                @"json",@"format", 
                                accountName,@"name",
                                nil];
    [aApi getOtherUserInfoWithParamters:requestDic delegate:self onSuccess:@selector(getOtherUserMsgSucc:) onFailure:@selector(getOtherUserMsgFail:)];
}

- (void)getOtherUserMsgSucc:(NSDictionary *)personInfo
{
    CLog(@"%s", __FUNCTION__);
    //	NSLog(@"获取的信息%@",personInfo);
	// 对返回的数据做验证处理，即如果返回的数据为空，则做响应的处理
	if (nil == personInfo || ![personInfo isKindOfClass:[NSDictionary class]]) {
        [self hiddenMBProgress];
        [self showErrorView:@"加载失败"];
		return;
	}
	id personDataDic = [DataCheck checkDictionary:personInfo forKey:@"data" withType:[NSDictionary class]];
	if (personDataDic == [NSNull null]) {
		[self hiddenMBProgress];
        [self showErrorView:@"加载失败"];
		return;
	}
    
	//NSDictionary *personDataDic = [personInfo objectForKey:@"data"];
	self.tempPersonMsgDic = personDataDic;
	[self tableViewDataSource];
	[self addTitleAndRightBarBtn];
	[self changeHeaderViewData];
	[self.listMsgView reloadData];
	[self hiddenMBProgress];
}
- (void)getOtherUserMsgFail:(NSError *)error
{
    [self hiddenMBProgress];
    CLog(@"%s, localizedDescription:%@", __FUNCTION__, [error localizedDescription]);
    [self showErrorView:@"加载失败"];
}

#pragma mark -
#pragma mark tableViewDelegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
	return 1;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section{
	if ([self.infoArray count] > 0) {
		CLog(@"[infoArray count]:%d", [infoArray count]);
		return [infoArray count] + 2;
	}else {
		return 2;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCellStyle style =  UITableViewCellStyleDefault;
    UITableViewCell *cell = nil;
    if (indexPath.row<2) {
       cell = [tableView dequeueReusableCellWithIdentifier:@"SpecialCell"];
    }else {
        //cell = [tableView dequeueReusableCellWithIdentifier:@"BaseCell"];
    }
	if (cell==nil) {
        if (indexPath.row<2) {
            cell = [[[UITableViewCell alloc] initWithStyle:style reuseIdentifier:@"SpecialCell"] autorelease];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }else {
            //cell = [[[UITableViewCell alloc] initWithStyle:style reuseIdentifier:@"BaseCell"] autorelease];
        }
    }
    switch (indexPath.row) {
        case 0:
            if (cellZero!=NULL) {
                [cellZero removeFromSuperview];
            }
           cellZero = [[CellZeroView alloc] init];
           cellZero.parentController = self;
           cellZero.dataMsgDic = [self.dataSourceArr objectAtIndex:indexPath.row];
           [cellZero constructFrame:CGRectMake(0, 0, 320, self.cell0Height)];
            cellZero.openStatus = self.cell0OpenStatus;
            cellZero.fisrtMark = self.first;
            [cell addSubview:cellZero];
            break;
        case 1:
            if (cellOne!=NULL) {
                [cellOne removeFromSuperview];
            }
            cellOne = [[CellOneView alloc] init];
            cellOne.parentController = self;
            cellOne.dataMsgDic = [self.dataSourceArr objectAtIndex:indexPath.row];
            [cellOne constructFrame:CGRectMake(0, 0, 320, 98)];
            [cell addSubview:cellOne];
            break;
        default:
		{
			NSUInteger row = indexPath.row - 2;
			UITableViewCell *tableViewCell = nil;
			
			if (row < [infoArray count]) {
				static NSString *cellIdentifier = @"broadcastCellIdentifier";
				HomelineCell *cell = (HomelineCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
				if (cell == nil) {
					cell = [[[HomelineCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier showStyle:HomeShowSytle sourceStyle:HomeSourceSytle containHead:NO] autorelease];
					cell.myHomelineCellVideoDelegate = self;
					cell.rootContrlType = self.pushControllerType;
					cell.contentView.backgroundColor = [UIColor whiteColor];
				} 
				Info *info = [infoArray objectAtIndex:row];
				
				cell.heightDic = self.heights;
				cell.remRow = [NSString stringWithFormat:@"%d", row];
				cell.homeInfo = info;
				[cell setLabelInfo:[infoArray objectAtIndex:row]];
				
				if (![[[infoArray objectAtIndex:row] source] isMemberOfClass:[NSNull class]]){
					if (info.source != nil) {
						TransInfo *transInfo = [self convertSourceToTransInfo:info.source];
						cell.sourceInfo = transInfo;
					}else {
						[cell remove];
					}
				}
				tableViewCell = cell;
				return tableViewCell;
			}
			else {
				NSString *cellIdentifier = @"cellIdentifier";
				UITableViewCell *tableViewCell1 = (UITableViewCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
				if (tableViewCell1 == nil) {
					tableViewCell1 = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
				}
				
				return tableViewCell1;
			}
		}
            break;
    }

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        [self moreMsgBtn];
    }else if (indexPath.row > 1) {
		[tableView deselectRowAtIndexPath:indexPath animated:YES];
		// 设置发送状态代理
		if (indexPath.row < [infoArray count] + 2) {
			DetailsPage   *details = [[DetailsPage alloc] init];
			details.homeInfo = [infoArray objectAtIndex:indexPath.row - 2];
            details.rootContrlType = self.pushControllerType;
			Info *info = [infoArray objectAtIndex:indexPath.row - 2];
			if (![info.source isMemberOfClass:[NSNull class]] && info.source != nil) {
				details.sourceInfo = [self convertSourceToTransInfo:info.source];
			}
			
			[self.navigationController pushViewController:details animated:YES];
			[details release];
		}
		else {
			//[self loadMoreStatuses];
			NSArray *indexPathes = [tableView indexPathsForVisibleRows];
			NSIndexPath *lastIndexPath = [indexPathes objectAtIndex:indexPathes.count-1];
			[tableView reloadData];
			[tableView scrollToRowAtIndexPath:lastIndexPath
							 atScrollPosition:UITableViewScrollPositionBottom animated:YES];
		}
	}
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.row == 0) {
		return self.cell0Height;
	}else if (indexPath.row == 1) {
		return 98;
	}else {
		if (indexPath.row < [self.infoArray count] + 2) {
			return [self getRowHeight:indexPath.row];
		}
		return 40;
	}
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {

    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}



/////////////////////////////////////////
- (TransInfo *)convertSourceToTransInfo:(NSDictionary *)tSource{
	TransInfo *transInfo = [[[TransInfo alloc] init] autorelease];
	if ([tSource valueForKey:@"name"] != nil) {
		transInfo.transName = [tSource valueForKey:@"name"];
	}
	if ([tSource valueForKey:@"nick"] != nil) {
		transInfo.transNick = [tSource valueForKey:@"nick"];
	}
	if ([tSource valueForKey:@"isvip"] != nil) {
		transInfo.transIsvip = [tSource valueForKey:@"isvip"];
	}
	if ([tSource valueForKey:@"origtext"] != nil) {
		transInfo.transOrigtext = [tSource valueForKey:@"origtext"];
	}
	if ([tSource valueForKey:@"id"] != nil) {
		transInfo.transId = [tSource valueForKey:@"id"];
	}
	if ([tSource valueForKey:@"image"] != nil&&![[tSource valueForKey:@"image"] isEqual:[NSNull null]]) {
		transInfo.transImage = [[tSource valueForKey:@"image"] objectAtIndex:0];
	}
	if ([tSource valueForKey:@"video"] != nil&&![[tSource valueForKey:@"video"] isEqual:[NSNull null]]) {
		if ([[tSource valueForKey:@"video"] valueForKey:@"picurl"] != nil) {
			transInfo.transVideo = [[tSource valueForKey:@"video"] valueForKey:@"picurl"];
		}
		transInfo.transVideoRealUrl = [[tSource valueForKey:@"video"] valueForKey:@"realurl"];
	}
	if ([tSource valueForKey:@"from"] != nil&&![[tSource valueForKey:@"from"] isEqual:[NSNull null]]) {
		transInfo.transFrom = [tSource valueForKey:@"from"];
	}
    if ([tSource valueForKey:@"timestamp"] != nil&&![[tSource valueForKey:@"timestamp"] isEqual:[NSNull null]]){
		transInfo.transTime = (NSString *)[tSource valueForKey:@"timestamp"];
	}
	if ([tSource valueForKey:@"is_auth"] != nil) {
		transInfo.translocalAuth = [NSString stringWithFormat:@"%@",[tSource objectForKey:@"is_auth"]];
	}
	CLog(@"%s,个人资料页本地认证:%@",__FUNCTION__,transInfo.translocalAuth);
	return transInfo;
}


// 点击返回按钮的时候调用
- (void)backBtnAction {
    [self.tabBarController performSelector:@selector(showNewTabBar) withObject:nil afterDelay:0.2f];
    [self.navigationController popViewControllerAnimated:YES];
}

// 根据指定的参数向服务器请求数据
-(void) requstWebService:(NSString *)pageflag:(NSString *)pagetime:(NSString *)type:(NSString *)contenttype{
	NSMutableDictionary *parameters = [[NSMutableDictionary alloc]initWithCapacity:10];
	[parameters setValue:@"json" forKey:@"format"];
	[parameters setValue:pageflag forKey:@"pageflag"];
	[parameters setValue:pagetime forKey:@"pagetime"];
	[parameters setValue:@"10" forKey:@"reqnum"];
	//[parameters setValue:@"123.321" forKey:@"wei"];
	[parameters setValue:self.accountName forKey:@"name"];
	[parameters setValue:self.lastid forKey:@"lastid"];
	[parameters setValue:@"0" forKey:@"type"];
	[parameters setValue:contenttype forKey:@"contenttype"];
	[parameters setValue:URL_USER_TIMELINE forKey:@"request_api"];
	
	[aApi getUserTimeLineWithParamters:parameters
							  delegate:self
							 onSuccess:@selector(requestSuccessCallBack:)
							 onFailure:@selector(requestFailureCallBack:)];
	
	[parameters release];
}

- (void)loadMoreStatuses{  //加载获取更多
	if (([[Reachability reachabilityForLocalWiFi] currentReachabilityStatus] == NotReachable) 
		&& ([[Reachability reachabilityForInternetConnection] currentReachabilityStatus] == NotReachable)){ 
		[self hiddenMBProgress1];
		[loadCell setState:errorInfo];
		listMsgView.tableFooterView = loadCell;
	}
	else {
		CLog(@"%s", __FUNCTION__);
		self.pushType = @"1";
		[self requstWebService:@"1":self.oldTime:@"0x0":@"0"];
	}
}

//- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollViewSender{

	NSArray *indexPathes = [listMsgView indexPathsForVisibleRows];
	if (indexPathes.count > 0) {
		int rowCounts = [listMsgView numberOfRowsInSection:0] - 2;
		NSIndexPath *lastIndexPath = [indexPathes objectAtIndex:indexPathes.count-1];
		//NSLog(@"row = %d", lastIndexPath.row);
		NSInteger length = rowCounts - lastIndexPath.row;
		if (_reloading && length < 2) {
			// 拉去完毕
			if (reachEnd) {
				[loadCell setState:loadFinished];
				//[self performSelector:@selector(handleTimer:) withObject:nil afterDelay:1];
			}
			else {
				[loadCell setState:loadMore1];
				// 2012-03-26 By Yi Minwen 防止多次调用加载更多，将_reloading放到外边来
				_reloading = NO;
				[self performSelector:@selector(handleTimer:) withObject:nil afterDelay:1];
			}
			
		}
	}

}


- (void)handleTimer:(NSTimer *)timer{
	[loadCell setState:loading1];
	[self loadMoreStatuses];
}

- (NSArray *)storeInfoToClass:(NSDictionary *)result{
	n = 0;
	NSMutableArray *syncInfoQueue = [NSMutableArray arrayWithCapacity:30];
	if (nil == result || ![result isKindOfClass:[NSDictionary class]]) {
		return syncInfoQueue;
	}
	
	id data = [DataCheck checkDictionary:result forKey:@"data" withType:[NSDictionary class]];
	if (data == [NSNull null]) {
		return syncInfoQueue;
	}
	id info = [DataCheck checkDictionary:data forKey:@"info" withType:[NSArray class]];
	if (info == [NSNull null]) {
		return syncInfoQueue;
	}
	
	if (info != nil && ![info isKindOfClass:[NSNull class]]) {
		for (NSDictionary *sts in info) {	
			if ([sts isKindOfClass:[NSDictionary class]] && sts) {
				Info *weiboInfo = [[Info alloc] init];
				weiboInfo.uid = [sts objectForKey:@"id"];
				weiboInfo.name = [sts objectForKey:@"name"];
				weiboInfo.nick = [sts objectForKey:@"nick"];
				weiboInfo.isvip = [NSString stringWithFormat:@"%@",[sts objectForKey:@"isvip"]];
				weiboInfo.origtext = [sts objectForKey:@"origtext"];
				weiboInfo.from = [sts objectForKey:@"from"];
				weiboInfo.timeStamp = [NSString stringWithFormat:@"%@",[sts objectForKey:@"timestamp"]];
				weiboInfo.type = [NSString stringWithFormat:@"%@",[sts objectForKey:HOMETYPE]];
				weiboInfo.emotionType = [NSString stringWithFormat:@"%@",[sts objectForKey:HOMEEMOTION]];
				weiboInfo.count = [NSString stringWithFormat:@"%@",[sts objectForKey:@"count"]];
				weiboInfo.mscount = [NSString stringWithFormat:@"%@",[sts objectForKey:@"mcount"]];
				weiboInfo.head = [sts objectForKey:@"head"];
				
				if (![[sts objectForKey:@"image"]isEqual:[NSNull null]]) {
					NSArray *imagelist = [[NSArray alloc]initWithArray:[sts objectForKey:@"image"]];
					if ([imagelist count]!=0) {
						NSString *image = [imagelist objectAtIndex:0];
						weiboInfo.image = image;
					}
					[imagelist release];
				}
				
				if (![[sts objectForKey:@"video"] isEqual:[NSNull null]]) {
					NSDictionary *video = [[NSDictionary alloc]initWithDictionary:[sts objectForKey:@"video"]];
					weiboInfo.video = video;
					[video release];
				}
				
				if (![[sts objectForKey:@"music"] isEqual:[NSNull null]]) {
					NSDictionary *musci = [[NSDictionary alloc] initWithDictionary:[sts objectForKey:@"music"]];
					weiboInfo.music = musci;	
					[musci release];
				}
				
				if (![[sts objectForKey:@"source"] isEqual:[NSNull null]]){
					NSDictionary *source = [[NSDictionary alloc] initWithDictionary:[sts objectForKey:@"source"]];
					weiboInfo.source =[NSDictionary dictionaryWithDictionary:[sts objectForKey:@"source"]];
					[source release];
				}
				
				[syncInfoQueue addObject:weiboInfo];
				
				if ([weiboInfo.timeStamp compare:nNewTime]== NSOrderedDescending) {
					n++;
				}
				[weiboInfo release];
			}	
		}
	}
	return syncInfoQueue;
}

// 请求数据成功的回调函数
-(void)requestSuccessCallBack:(NSDictionary *)result{
	NSArray *infoQu;
	Info *dataInfo ;
	_reloading = YES;
	infoQu =[self storeInfoToClass:result];
	if ([infoQu count] == 0) {
		[loadCell setState:loadMore1];
		return;
	}
	if ([pushType isEqualToString:@"2"]) {//首次请求网络
		for (int i=0; i<[infoQu count]; i++) {
			dataInfo = [infoQu objectAtIndex:i];
			[infoArray addObject:dataInfo];
		}
		
		self.sinceTime = [NSString stringWithFormat:@"%@",[[infoQu objectAtIndex:0] timeStamp]];
		self.nNewTime = self.sinceTime;
        int co = [infoQu count]-1;
		self.oldTime = [NSString stringWithFormat:@"%@",[[infoQu objectAtIndex:co]timeStamp]];
		self.lastid = [[infoQu objectAtIndex:[infoQu count]-1] uid];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}else if ([pushType isEqualToString:@"1"]) {//加载更多
		for (int i=0; i<[infoQu count]; i++) {
			dataInfo = [infoQu objectAtIndex:i];
			
			[infoArray addObject:dataInfo];
		}
		self.oldTime = [NSString stringWithFormat:@"%@",[[infoQu objectAtIndex:[infoQu count]-1] timeStamp]];
		self.lastid = [[infoQu objectAtIndex:[infoQu count]-1] uid];
		self.sinceTime = [NSString stringWithFormat:@"%@",[[infoQu objectAtIndex:0] timeStamp]];
	}
	
    [self hiddenMBProgress1];
	CLog(@"infoArray count:%d", [infoArray count]);
	[self.listMsgView reloadData];
	
	//reachEnd = ([infoQu count] == 30) ? YES:NO;
	// 因为前面已经做了类型检查，因此只要能够到这一步，就说明没有错误，因此不用做数据合法性的检查了
	reachEnd =  [[[result objectForKey:@"data"] objectForKey:@"hasnext"] intValue];
	if (reachEnd) {
		[loadCell setState:loadFinished];
		[loadCell.spinner stopAnimating];
	}else {
		[loadCell setState:loadMore1];
	}

	NSDictionary *data =[DataCheck checkDictionary:result forKey:@"data" withType:[NSDictionary class]];

	if ([data isKindOfClass:[NSDictionary class]]&&nil != [data objectForKey:@"user"]) {
			// 存储用户昵称
		NSDictionary *userNicks = [DataCheck checkDictionary:data forKey:@"user" withType:[NSDictionary class]];
		if ([userNicks isKindOfClass:[NSDictionary class]]) {
				// 存到数据库
			[DataManager insertUserInfoToDBWithDic:userNicks];
				// 存到本地字典
			[HomePage insertNickNameToDictionaryWithDic:userNicks];
		}
	}		
}

// 请求数据失败的回调函数
- (void)requestFailureCallBack:(NSError *)error{
	NSLog(@"userInfoTimeLine:%@",  [error localizedDescription]);
}

- (CGFloat)getRowHeight:(NSUInteger)row{
	NSString *rowString = [[NSString alloc] initWithFormat:@"%d", row - 2];
	if ([heights objectForKey:rowString]) {
		NSMutableDictionary *dic = [self.heights objectForKey:rowString];
		CGFloat origHeight = [[dic objectForKey:@"origHeight"] floatValue];
		CGFloat sourceHeight = [[dic objectForKey:@"sourceHeight"] floatValue];
		[rowString release];
		CGFloat retValue = 0.0f;
		if (sourceHeight > 1) {
			retValue += sourceHeight + VSBetweenSourceFrameAndFrom;
		}
		CGFloat fromHeight = [@"来自..." sizeWithFont:[UIFont systemFontOfSize:12]].height + VSpaceBetweenOriginFrameAndFrom;
		retValue += origHeight + fromHeight;
		return retValue;
	}
	else {
		Info *info = [infoArray objectAtIndex:row - 2];
		CGFloat origHeight = 0.0f;
		CGFloat sourceHeight = 0.0f;
		CGFloat retValue = 0.0f;
		origHeight = [MessageViewUtility getBroadcastOriginViewHeight:info];
		if (info.source != nil) {
			TransInfo *transInfo = [self convertSourceToTransInfo:info.source];
			sourceHeight = [MessageViewUtility getBroadcastSource:transInfo];
			retValue += sourceHeight + VSBetweenSourceFrameAndFrom;
		}
		// 来自...高度
		CGFloat fromHeight = [@"来自..." sizeWithFont:[UIFont systemFontOfSize:12]].height + VSpaceBetweenOriginFrameAndFrom;
		retValue += origHeight + fromHeight;
		
		NSMutableDictionary *dic = [[NSMutableDictionary alloc] initWithCapacity:2];
		NSString *origHeightStr = [[NSString alloc] initWithFormat:@"%f", origHeight];
		NSString *sourceHeightStr = [[NSString alloc] initWithFormat:@"%f", sourceHeight];
		[dic setObject:origHeightStr forKey:@"origHeight"];
		[dic setObject:sourceHeightStr forKey:@"sourceHeight"];
		[self.heights setObject:dic forKey:rowString];
		[origHeightStr release];
		[sourceHeightStr release];
		[dic release];
		[rowString release];
		return retValue;
	}
}

#pragma mark -
#pragma mark protocol OriginViewUrlDelegate<NSObject> 图片点击委托事件
- (void)OriginViewUrlClicked:(NSString *)urlSource {
	WebUrlViewController *webUrlViewController = [[WebUrlViewController alloc] init];
	webUrlViewController.webUrl = urlSource;
	[self.navigationController pushViewController:webUrlViewController animated:YES];
	[webUrlViewController release];
}

#pragma mark protocol OriginViewVideoDelegate<NSObject> 视频点击事件
- (void)OriginViewVideoClicked:(NSString *)urlVideo {
	WebUrlViewController *webUrlViewController = [[WebUrlViewController alloc] init];
	webUrlViewController.webUrl = urlVideo;
	[self.navigationController pushViewController:webUrlViewController animated:YES];
	[webUrlViewController release];
}

#pragma mark protocol SourceViewUrlDelegate<NSObject> 图片点击委托事件
- (void)SourceViewUrlClicked:(NSString *)urlSource {
	WebUrlViewController *webUrlViewController = [[WebUrlViewController alloc] init];
	webUrlViewController.webUrl = urlSource;
	[self.navigationController pushViewController:webUrlViewController animated:YES];
	[webUrlViewController release];
}

#pragma mark -
#pragma mark protocol HomelineCellVideoDelegate<NSObject> 视频点击事件
- (void)HomelineCellVideoClicked:(NSString *)urlVideo {	
	WebUrlViewController *webUrlViewController = [[WebUrlViewController alloc] init];
	webUrlViewController.webUrl = urlVideo;
	[self.navigationController pushViewController:webUrlViewController animated:YES];
	[webUrlViewController release];
}

@end
