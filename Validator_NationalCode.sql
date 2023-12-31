USE [DigitalLibrary]
GO
/****** Object:  UserDefinedFunction [dbo].[Validator_NationalCode]    Script Date: 06/03/2017 09:46:05 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Hale Kavoosi>
-- Create date: <06/03/2016>
-- Description:	<Description,--اين كد براي بررسي اعتبار كد ملي است ,>
-- =============================================
ALTER FUNCTION [dbo].[Validator_NationalCode]--اين كد براي بررسي اعتبار كد ملي است
(  @i_cod nvarchar(50)--كدملي

)

RETURNS bit--اگر كد ملي درست بود يك وگرنه صفر  را بر مي گرداند
AS
BEGIN


declare  @sum int  --مجموعاعداد  
declare @w  nvarchar(20)--براي پيدا كردن هر رقم 
declare @num int--شمارنده
declare @isnumber int--براي بررسي عدد  بودن كد ملي
declare @remind int
declare  @a int
set @num=1
set @remind=10
set @sum=0


set @isnumber=ISNumeric(@i_cod)	
if(len(@i_cod)=10 and @isnumber=1)begin
    while(@num<=9 and @remind>=2)
      begin
         set @w=substring(@i_cod,@num,1)--رقمها را يكي يكي جدا ميكند
         set @a=CAST(@w as int)
         set @sum=@sum+@a*@remind-- بدست آوردن مجموع رقمها*مكانشان
         set @num=@num+1
         set @remind=@remind-1
         
       end
       
         set @remind=@sum%11 
         if(@remind<2)    begin
           set @w=substring(@i_cod,10,1)-- بررسي  بيت اعتباركه اولين رقم از سمت چپ است
           if(@remind=@w)
                return 1
                             end
         else
           begin
         set @w=substring(@i_cod,10,1)-- بررسي  بيت اعتباركه اولين رقم از سمت چپ است
          --- set @remind=@sum %11 
    
             if(@w=11-@remind)
               return 1
           end
            
                            end
       
  return 0

  
END



--select [dbo].[Validator_NationalCode] (N'10')