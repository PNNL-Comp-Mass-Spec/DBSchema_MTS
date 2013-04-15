/****** Object:  Table [dbo].[DataDictionary_Fields] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DataDictionary_Fields](
	[SchemaName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[TableName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[FieldName] [sysname] COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[FieldDescription] [varchar](4000) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_DataDictionary_Fields] PRIMARY KEY CLUSTERED 
(
	[SchemaName] ASC,
	[TableName] ASC,
	[FieldName] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[DataDictionary_Fields] ADD  CONSTRAINT [DF_DataDictionary_FieldDescription]  DEFAULT ('') FOR [FieldDescription]
GO
