Use MT_Main

declare @result int

declare @newDBNameRoot varchar(64)
declare @newDBNameType char(1)
declare @description varchar(256)
declare @organism varchar(64)
declare @OrganismDBFileList varchar(1000)
declare @message varchar(512)

set @newDBNameRoot = 'MinT_Soil'
set @newDBNameType = 'A'
set @description = 'MinT_Soil_Microbiome samples'
set @organism = 'Microbial_Communities'
set @OrganismDBFileList = 'Kansas_Native_prairie_White-moleculo_LongRead_Tryp_Pig_Bov_2015-05-21.fasta'		-- List of Fasta files and/or protein collections to filter on; set to blank if not needed
set @message = ''

declare @dataStoragePath varchar(256)


exec @result = MakeNewPeptideDB
					@newDBNameRoot,
					@newDBNameType,
					@description,
					@organism,
					@OrganismDBFileList,
					@message output,
					@dataStoragePath = @dataStoragePath

GO
