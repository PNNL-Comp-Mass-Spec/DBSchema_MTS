/****** Object:  Table [dbo].[T_Analysis_Description_Updates] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_Analysis_Description_Updates](
	[Update_ID] [int] IDENTITY(1,1) NOT NULL,
	[Job] [int] NOT NULL,
	[Dataset] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset_New] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset_ID] [int] NULL,
	[Dataset_ID_New] [int] NULL,
	[Experiment] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Experiment_New] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Campaign] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Campaign_New] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Vol_Client] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Vol_Client_New] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Vol_Server] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Vol_Server_New] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Storage_Path] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Storage_Path_New] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Folder] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Dataset_Folder_New] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Results_Folder] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Results_Folder_New] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Completed] [datetime] NULL,
	[Completed_New] [datetime] NULL,
	[Parameter_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Parameter_File_Name_New] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Settings_File_Name] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Settings_File_Name_New] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Organism_DB_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Organism_DB_Name_New] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Collection_List] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Collection_List_New] [varchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Options_List] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_Options_List_New] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Separation_Sys_Type] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Separation_Sys_Type_New] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PreDigest_Internal_Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PreDigest_Internal_Std_New] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PostDigest_Internal_Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[PostDigest_Internal_Std_New] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset_Internal_Std] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Dataset_Internal_Std_New] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Enzyme_ID] [int] NULL,
	[Enzyme_ID_New] [int] NULL,
	[Labelling] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Labelling_New] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Entered] [datetime] NOT NULL,
 CONSTRAINT [PK_T_Analysis_Description_Updates] PRIMARY KEY CLUSTERED 
(
	[Update_ID] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

/****** Object:  Index [IX_T_Analysis_Description_Updates_Job] ******/
CREATE NONCLUSTERED INDEX [IX_T_Analysis_Description_Updates_Job] ON [dbo].[T_Analysis_Description_Updates] 
(
	[Job] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[T_Analysis_Description_Updates] ADD  CONSTRAINT [DF_T_Analysis_Description_Updates_Entered]  DEFAULT (getdate()) FOR [Entered]
GO
