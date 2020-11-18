# @String input_dir // set working directory
# @int channel_num	// set scan dimentions
# @int tile_num
# @int slice_num
# @int tile_overlap_perc
# @int grid_x_dim
# @int grid_y_dim
# @String spec_name
# @String grid_snake_direct
# @String tile_range

// Opera scan processor
// Performs flatfiled correction, slice maximum projections, tile stitching and channel overlay
// Bartek Tarkowski, LRB @ IIMCB
// August 2020
// Version 1.0

// FLATFIELD CORRECTION
function flatfieldCorr(input_dir , channels , slices , file_list) {
	// Make output directory for corrected images if does not exist
	if ( ! File.isDirectory(input_dir + "/Corrected") ) {File.makeDirectory(input_dir + "/Corrected");}

	for (c = 0 ; c < lengthOf(channels) ; c++) {	// loop thru channels
		for (s = 0 ; s < lengthOf(slices) ; s++) {	// loop thru slices
			for (i = 0; i < lengthOf(file_list); i++) {	// loop thru all files
				if (matches(file_list[i] , ".{9,10}(p" + slices[s] + "-ch" + channels[c] +").{14}" ) ) { 
			        open(input_dir + "/Images/" + file_list[i]);  
			    }
			}
			// Make stack, correct flatfield with default settings
			run("Images to Stack", "name=Stack title=[] use");
			run("BaSiC ", "processing_stack=Stack flat-field=None dark-field=None shading_estimation=[Estimate shading profiles] shading_model=[Estimate flat-field only (ignore dark-field)] setting_regularisationparametes=Automatic temporal_drift=Ignore correction_options=[Compute shading and correct images] lambda_flat=0.50 lambda_dark=0.50");
			// Close helper images
			selectWindow("Flat-field:Stack");
			close();
			selectWindow("Stack");
			close();

			// Split corrected stack, save images and close all
			selectWindow("Corrected:Stack");	
			run("Stack to Images");
			for (i=0 ; i < nImages ; i++) {
   	     	selectImage(i+1);
	        	saveAs("tiff", input_dir + "/Corrected/" + getTitle);
				} 
			run("Close All");
			}
		}
	}


// PERFORM MAX PROJECTION FOR EACH TILE AND CHANNEL
function maxProject(input_dir , channels , tiles , file_list){
	
	// Make output directory for projections if does not exist
	if ( ! File.isDirectory(input_dir + "/Projections") ) {File.makeDirectory(input_dir + "/Projections");}
	
	for (c = 0 ; c < lengthOf(channels) ; c++) {	// loop thru channels
		for (t = 0 ; t < lengthOf(tiles) ; t++) {	// loop thru tiles
			for (i = 0; i < lengthOf(file_list); i++) {	// loop thru all files
				// and open only images matching current channel and tile
				if (matches(file_list[i] , ".{6}(f" + tiles[t]+ ").{3}" + "(-ch" + channels[c] +").{14}" ) ) { 
			        open(input_dir + "/Corrected/" + file_list[i]);  
			    }
			}
			// Make stack, make projections, save and close files
			run("Images to Stack", "name=Stack title=[] use");
			run("Z Project...", "projection=[Max Intensity]");
			saveAs("Tiff", input_dir + "/Projections/f" +  tiles[t] + "-ch" + channels[c] + ".tif");
			close();
			close();
			}
		}
	}

// RENAME PROJECTION FILES TO CORRECT ORDER
function selectTiles(input_dir , channels , tile_range) {

	// generate an array with ordered selected tile numbers
	tile_ranges = split(tile_range , ",");
	tile_order = newArray();
	for (r = 0 ; r < tile_ranges.length ; r++){
		if (tile_ranges[r].contains("-")){
			range = split(tile_ranges[r] , "-");
			start = range[0];
			stop = range[1];
			part_range = Array.slice(Array.getSequence(stop + 1) , start);
			tile_order = Array.concat(tile_order , part_range );
			}else{
			tile_order = Array.concat(tile_order , tile_ranges[r]);	
			}
		}

	// Make output directory for projections if does not exist
	spec_project_dir = "/Projections/" + spec_name + "/";
	if ( ! File.isDirectory(input_dir + spec_project_dir) ) {File.makeDirectory(input_dir + spec_project_dir);}

	// move selected tiles to a subdirectory, correct order and reformat numbering to 3 digits
	for (c = 0; c < lengthOf(channels); c++) {	// Loop thru channels
		for (t = 0 ; t < tile_order.length ; t++) {		// Loop thru ordered tile numbers
			File.rename(input_dir + "/Projections/" + "f" + IJ.pad(tile_order[t] , 2) + "-ch" + channels[c] + ".tif" , 
						input_dir + spec_project_dir + "f" + IJ.pad(t + 1 , 3) + "-ch" + channels[c] + ".tif" );
			}
		}
	}

// GRID STITCHING
function stitchGrid(input_dir , channels , grid_x_dim , grid_y_dim , tile_overlap_perc , spec_name) {
	// Make output directory for stitcing plugin if does not exist
	spec_stitch_dir = "Stitches/" + spec_name + "/";
	if ( ! File.isDirectory(input_dir + spec_stitch_dir) ) {
		File.makeDirectory(input_dir + "Stitches/");
		File.makeDirectory(input_dir + spec_stitch_dir);
		}
	if (grid_snake_direct.toLowerCase == "left") {grid_snake_text = "[Left & Down]";}
	else {grid_snake_text = "[Right & Down                ]";}
	for (c = 0; c < lengthOf(channels); c++) {	
		if ( ! File.isDirectory(input_dir + spec_stitch_dir + "ch" + channels[c]) )
			{File.makeDirectory(input_dir + spec_stitch_dir + "ch" + channels[c]);}
		run("Grid/Collection stitching", "type=[Grid: snake by rows] order=" + grid_snake_text + 
			" grid_size_x=" + grid_x_dim + " grid_size_y=" + grid_y_dim + 
			" tile_overlap=" + tile_overlap_perc + " first_file_index_i=1" +
			" directory=" + input_dir + "/Projections/" + spec_name + "/"+ 
			" file_names=f{iii}-ch" + channels[c] + ".tif" +
			" output_textfile_name=TileConfiguration.txt" +
			" fusion_method=[Linear Blending] regression_threshold=0.30 max/avg_displacement_threshold=2.50 absolute_displacement_threshold=3.50" +
			" compute_overlap computation_parameters=[Save memory (but be slower)]" +
			" image_output=[Write to disk] output_directory=" + input_dir + spec_stitch_dir + "ch" + channels[c]);
		}
	}


// SETUP ARRAYS FOR LOOPING

// Fill arrays with formatted for channel, tile and slice numbers
channels = newArray(channel_num);
for (i = 0 ; i < channel_num ; i++) {channels[i] = i + 1;}
tiles = newArray(tile_num);
for (i = 0 ; i < tile_num ; i++) {tiles[i] = IJ.pad(i + 1 , 2); }
slices = newArray(slice_num);
for (i = 0 ; i < slice_num ; i++) {slices[i] = IJ.pad(i + 1 , 2); }

// Get file list
file_list = getFileList(input_dir + "/Images");

// Run without image display
setBatchMode(true);

// run flatfield correction
flatfieldCorr(input_dir , channels , slices , file_list);
// run max projection
maxProject(input_dir , channels , tiles , file_list);
// select tiles
selectTiles(input_dir , channels , tile_range);
// stitch selected tiles
stitchGrid(input_dir , channels , grid_x_dim , grid_y_dim , tile_overlap_perc , spec_name);