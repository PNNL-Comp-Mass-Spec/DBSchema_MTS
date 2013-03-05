/****** Object:  Table [dbo].[T_DMS_Analysis_Job_Info_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Analysis_Job_Info_Cached](
	[Job] [int] NOT NULL,
	[RequestID] [int] NOT NULL,
	[Priority] [int] NOT NULL,
	[Dataset] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Experiment] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Campaign] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DatasetID] [int] NOT NULL,
	[Organism] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[InstrumentName] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[InstrumentClass] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[AnalysisTool] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Processor] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Completed] [datetime] NULL,
	[ParameterFileName] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[SettingsFileName] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[OrganismDBName] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ProteinCollectionList] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ProteinOptions] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[StoragePathClient] [varchar](8000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[StoragePathServer] [varchar](4096) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DatasetFolder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ResultsFolder] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Owner] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Comment] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SeparationSysType] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ResultType] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset Int Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[DS_created] [datetime] NOT NULL,
	[DS_Acq_Length] [decimal](9, 2) NULL,
	[EnzymeID] [int] NOT NULL,
	[Labelling] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PreDigest Int Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[PostDigest Int Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Last_Affected] [datetime] NULL,
 CONSTRAINT [PK_T_DMS_Analysis_Job_Info_Cached] PRIMARY KEY CLUSTERED 
(
	[Job] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

/****** Object:  Index [IX_T_DMS_Analysis_Job_Info_Cached_Dataset] ******/
CREATE NONCLUSTERED INDEX [IX_T_DMS_Analysis_Job_Info_Cached_Dataset] ON [dbo].[T_DMS_Analysis_Job_Info_Cached] 
(
	[Dataset] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO

/****** Object:  Index [IX_T_DMS_Analysis_Job_Info_Cached_Experiment] ******/
CREATE NONCLUSTERED INDEX [IX_T_DMS_Analysis_Job_Info_Cached_Experiment] ON [dbo].[T_DMS_Analysis_Job_Info_Cached] 
(
	[Experiment] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
/****** Object:  Trigger [dbo].[trig_u_DMS_Analysis_Job_Info_Cached] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE Trigger [dbo].[trig_u_DMS_Analysis_Job_Info_Cached] on [dbo].[T_DMS_Analysis_Job_Info_Cached]
For Update
AS
	If @@RowCount = 0
		Return

	If update(Job) OR
       update(RequestID) OR
	   update(Priority) OR
	   update(Dataset) OR
	   update(Experiment) OR
	   update(Campaign) OR
	   update(DatasetID) OR
	   update(Organism) OR
	   update(InstrumentName) OR
	   update(InstrumentClass) OR
	   update(AnalysisTool) OR
       update(Processor) OR
	   update(Completed) OR
	   update(ParameterFileName) OR
	   update(SettingsFileName) OR
	   update(OrganismDBName) OR
	   update(ProteinCollectionList) OR
	   update(ProteinOptions) OR
	   update(StoragePathClient) OR
	   update(StoragePathServer) OR
	   update(DatasetFolder) OR
	   update(ResultsFolder) OR
	   update(Owner) OR
	   update(Comment) OR
	   update(SeparationSysType) OR
	   update(ResultType) OR
	   update([Dataset Int Std]) OR
	   update(DS_created) OR
	   update(DS_Acq_Length) OR
	   update(EnzymeID) OR
	   update(Labelling) OR
	   update([PreDigest Int Std]) OR
	   update([PostDigest Int Std])
	Begin
			UPDATE T_DMS_Analysis_Job_Info_Cached
			SET Last_Affected = GetDate()
			FROM T_DMS_Analysis_Job_Info_Cached AJ INNER JOIN 
				 inserted ON AJ.Job = inserted.Job
	End

GO
ALTER TABLE [dbo].[T_DMS_Analysis_Job_Info_Cached] ADD  CONSTRAINT [DF_T_DMS_Analysis_Job_Info_Cached_RequestID]  DEFAULT ((1)) FOR [RequestID]
GO
ALTER TABLE [dbo].[T_DMS_Analysis_Job_Info_Cached] ADD  CONSTRAINT [DF_T_DMS_Analysis_Job_Info_Cached_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
