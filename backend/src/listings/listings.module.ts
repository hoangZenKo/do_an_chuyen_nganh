import { Module } from '@nestjs/common';
import { AdminListingsController, LandlordListingsController, PublicListingsController, PublicCampusesController, AdminCampusesController, StudentListingsController } from './listings.controller';
import { ListingsService } from './listings.service';
import { SavedSearchesController } from './saved-searches.controller';
import { SavedSearchesService } from './saved-searches.service';

@Module({ controllers: [SavedSearchesController, PublicListingsController, LandlordListingsController, AdminListingsController, PublicCampusesController, AdminCampusesController, StudentListingsController], providers: [ListingsService, SavedSearchesService], exports: [ListingsService] })
export class ListingsModule {}
