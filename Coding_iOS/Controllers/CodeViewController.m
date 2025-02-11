//
//  CodeViewController.m
//  Coding_iOS
//
//  Created by 王 原闯 on 14/10/30.
//  Copyright (c) 2014年 Coding. All rights reserved.
//

#import "CodeViewController.h"
#import "Coding_NetAPIManager.h"
#import "WebContentManager.h"
#import "ProjectCommitsViewController.h"
#import "ProjectViewController.h"

@interface CodeViewController ()
@property (strong, nonatomic) UIWebView *webContentView;
@property (strong, nonatomic) UIActivityIndicatorView *activityIndicator;

@end

@implementation CodeViewController

+ (CodeViewController *)codeVCWithProject:(Project *)project andCodeFile:(CodeFile *)codeFile{
    CodeViewController *vc = [[CodeViewController alloc] init];
    vc.myProject = project;
    vc.myCodeFile = codeFile;
    return vc;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = [[_myCodeFile.path componentsSeparatedByString:@"/"] lastObject];
    
    {
        //用webView显示内容
        _webContentView = [[UIWebView alloc] initWithFrame:self.view.bounds];
        _webContentView.delegate = self;
        _webContentView.backgroundColor = [UIColor clearColor];
        _webContentView.opaque = NO;
        _webContentView.scalesPageToFit = YES;
        [self.view addSubview:_webContentView];
        //webview加载指示
        _activityIndicator = [[UIActivityIndicatorView alloc]
                              initWithActivityIndicatorStyle:
                              UIActivityIndicatorViewStyleGray];
        _activityIndicator.hidesWhenStopped = YES;
        [_activityIndicator setCenter:CGPointMake(CGRectGetWidth(_webContentView.frame)/2, CGRectGetHeight(_webContentView.frame)/2)];
        [_webContentView addSubview:_activityIndicator];
        [_webContentView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.view);
        }];
    }
    [self sendRequest];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Orientations
- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark Request

- (void)sendRequest{
    [self.view beginLoading];
    __weak typeof(self) weakSelf = self;
    if (_myCodeFile.ref.length <= 0 && [_myCodeFile.path isEqualToString:@"README"]) {
        [[Coding_NetAPIManager sharedManager] request_ReadMeOFProject:_myProject andBlock:^(id data, NSError *error) {
            [weakSelf doSomethingWithResponse:data andError:error];
        }];
    }else{
        [[Coding_NetAPIManager sharedManager] request_CodeFile:_myCodeFile withPro:_myProject andBlock:^(id data, NSError *error) {
            [weakSelf doSomethingWithResponse:data andError:error];
            [weakSelf configRightNavBtn];
        }];
    }
}

- (void)doSomethingWithResponse:(id)data andError:(NSError *)error{
    [self.view endLoading];
    if ([data isKindOfClass:[CodeFile class]]) {
        self.myCodeFile = data;
        [self refreshCodeViewData];
    }else{
        self.myCodeFile = [CodeFile codeFileWithMDStr:data];
        [self refreshCodeViewData];
    }
    [self.view configBlankPage:EaseBlankPageTypeView hasData:(data != nil) hasError:(error != nil) reloadButtonBlock:^(id sender) {
        [self sendRequest];
    }];
}

- (void)refreshCodeViewData{
    if ([_myCodeFile.file.mode isEqualToString:@"image"]) {
//        NSURL *imageUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@u/%@/p/%@/git/raw/%@", [NSObject baseURLStr], _myProject.owner_user_name, _myProject.name, [NSString handelRef:_myCodeFile.ref path:_myCodeFile.file.path]]];
        NSURL *imageUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@u/%@/p/%@/git/raw/%@/%@", [NSObject baseURLStr], _myProject.owner_user_name, _myProject.name, _myCodeFile.ref, _myCodeFile.file.path]];
        DebugLog(@"imageUrl: %@", imageUrl);
        [self.webContentView loadRequest:[NSURLRequest requestWithURL:imageUrl]];
    }else if ([_myCodeFile.file.mode isEqualToString:@"file"] ||
              [_myCodeFile.file.mode isEqualToString:@"sym_link"]){
        NSString *contentStr = [WebContentManager codePatternedWithContent:_myCodeFile];
        [self.webContentView loadHTMLString:contentStr baseURL:nil];
    }
}

#pragma mark UIWebViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType{
    DebugLog(@"strLink=[%@]",request.URL.absoluteString);
    if ([_myCodeFile.file.mode isEqualToString:@"image"]) {
        NSString *imageStr = [NSString stringWithFormat:@"%@u/%@/p/%@/git/raw/%@/%@", [NSObject baseURLStr], _myProject.owner_user_name, _myProject.name, _myCodeFile.ref, _myCodeFile.file.path];
        if ([imageStr isEqualToString:request.URL.absoluteString]) {
            return YES;
        }
    }
    UIViewController *vc = [BaseViewController analyseVCFromLinkStr:request.URL.absoluteString];
    if (vc) {
        [self.navigationController pushViewController:vc animated:YES];
        return NO;
    }
    return YES;
}
- (void)webViewDidStartLoad:(UIWebView *)webView{
    [_activityIndicator startAnimating];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView{
    [_activityIndicator stopAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
    if([error code] == NSURLErrorCancelled)
        return;
    else
        DebugLog(@"%@", error.description);
}

#pragma mark Nav
- (void)configRightNavBtn{
    if (!self.navigationItem.rightBarButtonItem) {
        [self.navigationItem setRightBarButtonItem:[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"moreBtn_Nav"] style:UIBarButtonItemStylePlain target:self action:@selector(rightNavBtnClicked)] animated:NO];
    }
}

- (void)rightNavBtnClicked{
    __weak typeof(self) weakSelf = self;
    [[UIActionSheet bk_actionSheetCustomWithTitle:nil buttonTitles:@[@"查看提交记录", @"退出代码查看"] destructiveTitle:nil cancelTitle:@"取消" andDidDismissBlock:^(UIActionSheet *sheet, NSInteger index) {
        switch (index) {
            case 0:{
                [weakSelf goToCommitsVC];
            }
                break;
            case 1:{
                [weakSelf.navigationController.viewControllers enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(UIViewController *obj, NSUInteger idx, BOOL *stop) {
                    if (![obj isKindOfClass:[weakSelf class]]) {
                        if ([obj isKindOfClass:[ProjectViewController class]]) {
                            if ([(ProjectViewController *)obj curType] != ProjectViewTypeCodes) {
                                *stop = YES;
                            }
                        }else{
                            *stop = YES;
                        }
                    }
                    if (*stop) {
                        [weakSelf.navigationController popToViewController:obj animated:YES];
                    }
                }];
            }
                break;
            default:
                break;
        }
    }] showInView:self.view];
}

- (void)goToCommitsVC{
    ProjectCommitsViewController *vc = [ProjectCommitsViewController new];
    vc.curProject = self.myProject;
    vc.curCommits = [Commits commitsWithRef:self.myCodeFile.ref Path:self.myCodeFile.path];
    [self.navigationController pushViewController:vc animated:YES];
}

@end
