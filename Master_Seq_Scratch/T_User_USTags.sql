/****** Object:  Table [dbo].[T_User_USTags] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[T_User_USTags](
	[Entry_ID] [int] IDENTITY(1,1) NOT NULL,
	[Problematic] [varchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Peptide] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Clean_Sequence] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Gene] [varchar](64) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Mass] [float] NOT NULL,
	[NET] [real] NOT NULL,
	[Charge] [smallint] NULL,
	[Hpexperiment] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[EBCPexperiment] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Protein_NCBI] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Desc_NCBI] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[Mass_Tag_ID] [int] NULL,
	[Mod_Count] [int] NULL,
	[Mod_Description] [varchar](2048) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[Monoisotopic_Mass] [float] NULL,
	[GANET_Predicted] [real] NULL,
 CONSTRAINT [PK_T_User_USTags] PRIMARY KEY CLUSTERED 
(
	[Entry_ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
