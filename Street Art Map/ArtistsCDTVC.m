//
//  ArtistsCDTVC.m
//  Street Art Map
//
//  Created by Alex Smith on 12/07/2015.
//  Copyright (c) 2015 Alex Smith. All rights reserved.
//

#import "ArtistsCDTVC.h"
#import "Artist.h"
#import "Artist+Equality.h"
#import "Artist+Create.h"
#import "ArtworksForArtistCDTVC.h"
#import "Artwork.h"
#import "PhotoLibraryInterface.h"
#import "ArtistTableViewCell.h"
#import "GridVC.h"

@interface ArtistsCDTVC ()

@property (strong, nonatomic) NSString *cellIdentifier;
@property (strong, nonatomic) NSMutableArray *artworkImageGridVCs;
@property (strong, nonatomic) NSMutableDictionary *artworksForArtists;
@property (strong, nonatomic) NSMutableDictionary *cachedImages;

@end

@implementation ArtistsCDTVC

#pragma mark - Properties

-(NSMutableArray *)artworkImageGridVCs
{
    if (!_artworkImageGridVCs) {
        _artworkImageGridVCs = [NSMutableArray array];
    }
    
    return _artworkImageGridVCs;
}

-(NSMutableDictionary *)artworksForArtists
{
    if (!_artworksForArtists) {
        _artworksForArtists = [NSMutableDictionary dictionary];
    }
    
    return _artworksForArtists;
}

-(NSMutableDictionary *)cachedImages
{
    if (!_cachedImages) {
        _cachedImages = [NSMutableDictionary dictionary];
    }
    
    return _cachedImages;
}

-(void)setScreenMode:(ArtistScreenMode)screenMode
{
    _screenMode = screenMode;
    if (self.screenMode == ViewingMode) {
        self.cellIdentifier = @"ArtistViewCell";
        self.navigationItem.title = @"Artists";
    } else if (self.screenMode == SelectionMode) {
        self.cellIdentifier = @"ArtistSelectCell";
        self.navigationItem.title = @"Select Artist";
        UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel:)];
        self.navigationItem.leftBarButtonItem = cancelButton;
    }
}

#pragma mark - View Life Cycle

#define CELL_IDENTIFIER @"ArtistTableViewCell"

-(void)viewDidLoad
{
    self.screenMode = ViewingMode;
    UINib *nib = [UINib nibWithNibName:@"ArtistTableViewCell" bundle:nil];
    [self.tableView registerNib:nib forCellReuseIdentifier:CELL_IDENTIFIER];
}

#pragma mark - Abstract Methods

-(void)setupFetchedResultsController
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Artist"];
    NSSortDescriptor *nameSort = [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES];
    request.sortDescriptors = @[nameSort];
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request managedObjectContext:self.context sectionNameKeyPath:nil cacheName:nil];
    
    //for (Artist *artist in [self.fetchedResultsController fetchedObjects])
    //    self.artworksForArtists[artist.name] = artist.artworks;
}

#pragma mark - UITableViewDelegate

-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [ArtistTableViewCell cellHeight];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *segueIdentifier = self.screenMode == ViewingMode ?
                                    @"Show Artwork For Artist" : @"Select Artist Unwind";
    
    [self performSegueWithIdentifier:segueIdentifier
                              sender:[self.tableView cellForRowAtIndexPath:indexPath]];
}

#pragma mark - UITableViewDataSource

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    ArtistTableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER];
    Artist *artist = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.nameLabel.text = artist.name;
    
    if (!self.artworksForArtists[artist.name])
        self.artworksForArtists[artist.name] = artist.artworks;

    NSArray *artworksForArtist = [self.artworksForArtists[artist.name] allObjects];
    
    GridVC *artworkImagesCVC = [[GridVC alloc] initWithgridSize:(GridSize){1, 16} collectionView:cell.artworkImagesCV andCellConfigureBlock:^(UICollectionViewCell *cvc, Position position, int index) {
        cvc.backgroundView = [[UIView alloc] init];
        cvc.backgroundView.layer.borderColor = [UIColor whiteColor].CGColor;
        cvc.backgroundView.layer.borderWidth = 0.5;

        UIImageView *artworkImageView;
        if ([cvc.backgroundView.subviews count]) {
            if ([[cvc.backgroundView.subviews firstObject] isMemberOfClass:[UIImageView class]]) {
                artworkImageView = (UIImageView *)[cvc.backgroundView.subviews firstObject];
                artworkImageView.image = nil;
            }
        } else {
            artworkImageView = [[UIImageView alloc] initWithFrame:cvc.bounds];
            artworkImageView.clipsToBounds = YES;
            [cvc.backgroundView addSubview:artworkImageView];
        }
        
        if (index < [artworksForArtist count]) {
            Artwork *artworkToDisplayImageFor = artworksForArtist[index];
            
            if (!self.cachedImages[artworkToDisplayImageFor.imageLocation]) {
                //[[PhotoLibraryInterface sharedLibrary] setImageInImageView:artworkImageView toImageWithLocalIdentifier:artworkToDisplayImageFor.imageLocation andExecuteBlockOnceImageFetched:^{}];
                [[PhotoLibraryInterface sharedLibrary] imageWithLocalIdentifier:artworkToDisplayImageFor.imageLocation size:artworkImageView.bounds.size completion:^(UIImage *image) {
                    artworkImageView.image = image;
                    self.cachedImages[artworkToDisplayImageFor.imageLocation] = image;
                }];
            } else {
                artworkImageView.image = self.cachedImages[artworkToDisplayImageFor.imageLocation];
            }
        }
    }];
    [self.artworkImageGridVCs addObject:artworkImagesCVC];
    
#warning - The table should auto scroll to the selected artist (might be offscreen)
    if (self.screenMode == SelectionMode && [self.selectedArtist isEqualToArtist:artist]) {
        cell.backgroundColor = [UIColor lightGrayColor];
    } else {
        cell.backgroundColor = [UIColor whiteColor];
    }
    
    return cell;
}

#pragma mark - Segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([sender isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell *cellSelected = (UITableViewCell *)sender;
        NSIndexPath *pathOfSelectedCell = [self.tableView indexPathForCell:cellSelected];
        self.selectedArtist = [self.fetchedResultsController objectAtIndexPath:pathOfSelectedCell];
        
        if ([segue.identifier isEqualToString:@"Show Artwork For Artist"]) {
            if ([segue.destinationViewController isMemberOfClass:[ArtworksForArtistCDTVC class]]) {
                ArtworksForArtistCDTVC *artworksForSelectedArtist = (ArtworksForArtistCDTVC *)segue.destinationViewController;
                artworksForSelectedArtist.artistToShowPhotosFor = self.selectedArtist;
                artworksForSelectedArtist.context = self.context;
            }
        }
    }
}

#pragma mark - Actions

- (IBAction)cancel:(UIBarButtonItem *)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:NULL];
}

- (IBAction)addArtist:(UIBarButtonItem *)sender
{
    UIAlertController *newArtistAlert = [UIAlertController alertControllerWithTitle:@"New Artist" message:@"Please type the artist's name" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                     style:UIAlertActionStyleCancel
                                                   handler:NULL];
    [newArtistAlert addAction:cancelAction];
    
#warning THIS MIGHT CREATE A STRONG REFERECNE CYCLE
    
    UIAlertAction *addArtistAction = [UIAlertAction actionWithTitle:@"Add"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
            NSString *newArtistName = ((UITextField *)[newArtistAlert.textFields firstObject]).text;
            self.selectedArtist = [Artist artistWithName:newArtistName inManagedObjectContext:self.context];
            
            if (self.screenMode == SelectionMode)
                [self performSegueWithIdentifier:@"Select Artist Unwind" sender:newArtistAlert];
    }];
    [newArtistAlert addAction:addArtistAction];
    
    [newArtistAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    
    [self presentViewController:newArtistAlert animated:YES completion:NULL];
}

@end
