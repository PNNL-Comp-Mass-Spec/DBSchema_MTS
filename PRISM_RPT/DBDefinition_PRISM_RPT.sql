/****** Object:  Database [PRISM_RPT] ******/
CREATE DATABASE [PRISM_RPT] ON  PRIMARY 
( NAME = N'PRISM_RPT_Data', FILENAME = N'I:\SQLServerData\PRISM_RPT_data.mdf' , SIZE = 135744KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 LOG ON 
( NAME = N'PRISM_RPT_Log', FILENAME = N'H:\SQLServerData\PRISM_RPT_log.ldf' , SIZE = 121280KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 COLLATE SQL_Latin1_General_CP1_CI_AS
GO
ALTER DATABASE [PRISM_RPT] SET COMPATIBILITY_LEVEL = 100
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [PRISM_RPT].[dbo].[sp_fulltext_database] @action = 'disable'
end
GO
ALTER DATABASE [PRISM_RPT] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [PRISM_RPT] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [PRISM_RPT] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [PRISM_RPT] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [PRISM_RPT] SET ARITHABORT OFF 
GO
ALTER DATABASE [PRISM_RPT] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [PRISM_RPT] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [PRISM_RPT] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [PRISM_RPT] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [PRISM_RPT] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [PRISM_RPT] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [PRISM_RPT] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [PRISM_RPT] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [PRISM_RPT] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [PRISM_RPT] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [PRISM_RPT] SET  DISABLE_BROKER 
GO
ALTER DATABASE [PRISM_RPT] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [PRISM_RPT] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [PRISM_RPT] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [PRISM_RPT] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [PRISM_RPT] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [PRISM_RPT] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [PRISM_RPT] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [PRISM_RPT] SET  READ_WRITE 
GO
ALTER DATABASE [PRISM_RPT] SET RECOVERY FULL 
GO
ALTER DATABASE [PRISM_RPT] SET  MULTI_USER 
GO
ALTER DATABASE [PRISM_RPT] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [PRISM_RPT] SET DB_CHAINING OFF 
GO
GRANT CONNECT TO [d3j409] AS [dbo]
GO
GRANT CONNECT TO [D3J410] AS [dbo]
GO
GRANT CONNECT TO [d3m306] AS [dbo]
GO
GRANT CONNECT TO [d3m578] AS [dbo]
GO
GRANT CONNECT TO [msdadmin] AS [dbo]
GO
GRANT CONNECT TO [MTAdmin] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Dev] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Dev] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Lite] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Lite] AS [dbo]
GO
GRANT CONNECT TO [MTS_DB_Reader] AS [dbo]
GO
GRANT SHOWPLAN TO [MTS_DB_Reader] AS [dbo]
GO
GRANT CONNECT TO [MTUser] AS [dbo]
GO
GRANT SHOWPLAN TO [MTUser] AS [dbo]
GO
