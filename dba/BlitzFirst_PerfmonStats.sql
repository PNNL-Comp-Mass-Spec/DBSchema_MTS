/****** Object:  Table [dbo].[BlitzFirst_PerfmonStats] ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[BlitzFirst_PerfmonStats](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[CheckDate] [datetimeoffset](7) NULL,
	[object_name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[counter_name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[instance_name] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[cntr_value] [bigint] NULL,
	[cntr_type] [int] NOT NULL,
	[value_delta] [bigint] NULL,
	[value_per_second] [decimal](18, 2) NULL,
 CONSTRAINT [PK_EA59E5CE-7EC3-4BA5-81F8-904EF7F90F5D] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
