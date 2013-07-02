/****** Object:  Table [dbo].[dn_handleCount] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[dn_handleCount](
	[handle] [varchar](20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[batch_type] [char](3) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[ss_cnt] [int] NOT NULL,
	[rs_cnt] [int] NULL,
	[rs_validated_cnt] [int] NULL,
	[create_time] [smalldatetime] NOT NULL
) ON [PRIMARY]

GO
