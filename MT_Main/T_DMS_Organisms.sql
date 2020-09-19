/****** Object:  Table [dbo].[T_DMS_Organisms] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_DMS_Organisms](
	[Organism_ID] [int] NOT NULL,
	[Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Description] [varchar](512) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Short_Name] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Domain] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Kingdom] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Phylum] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Class] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Order] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Family] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Genus] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Species] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Strain] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[DNA_Translation_Table_ID] [int] NULL,
	[Mito_DNA_Translation_Table_ID] [int] NULL,
	[Created_DMS] [datetime] NULL,
	[Active] [tinyint] NULL,
	[OrganismDBPath] [varchar](256) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Cached_RowVersion] [binary](8) NOT NULL,
	[Last_Affected] [datetime] NOT NULL,
 CONSTRAINT [PK_T_DMS_Organisms] PRIMARY KEY CLUSTERED 
(
	[Organism_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY],
 CONSTRAINT [IX_T_DMS_Organisms_Name] UNIQUE NONCLUSTERED 
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[T_DMS_Organisms] ADD  CONSTRAINT [DF_T_DMS_Organisms_Last_Affected]  DEFAULT (getdate()) FOR [Last_Affected]
GO
