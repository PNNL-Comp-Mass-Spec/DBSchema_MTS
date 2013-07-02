/****** Object:  Table [dbo].[Allele] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Allele](
	[allele_id] [int] NOT NULL,
	[allele] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[create_time] [smalldatetime] NOT NULL,
	[rev_allele_id] [int] NULL,
	[src] [varchar](10) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[last_updated_time] [smalldatetime] NULL,
 CONSTRAINT [PK_Allele] PRIMARY KEY CLUSTERED 
(
	[allele_id] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
