/****** Object:  Table [dbo].[SnpFunctionCode] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SnpFunctionCode](
	[code] [tinyint] NOT NULL,
	[abbrev] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[descrip] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[create_time] [smalldatetime] NOT NULL,
	[top_level_class] [char](5) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[is_coding] [tinyint] NOT NULL,
	[is_exon] [bit] NULL,
	[var_prop_effect_code] [int] NULL,
	[var_prop_gene_loc_code] [int] NULL,
	[SO_id] [varchar](32) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_SnpFunctionCode] PRIMARY KEY CLUSTERED 
(
	[code] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
