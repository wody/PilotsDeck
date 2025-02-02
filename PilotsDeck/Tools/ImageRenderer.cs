﻿using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Drawing.Text;
using System.IO;

namespace PilotsDeck
{
    public class Arc
    {
        public float Radius { get; set; } = 48;
        public float Width { get; set; } = 6;
        public PointF Offset { get; set; } = new PointF(0, 0);
        public float StartAngle { get; set; } = 135;
        public float SweepAngle { get; set; } = 180;

        public RectangleF GetRectangle(float buttonSize, float sizeScalar)
        {
            float org = ((buttonSize - Radius * sizeScalar) / 2.0f); // btn - <R> / 2 => x/y
            return new RectangleF(org + Offset.X, org + Offset.Y, Radius * sizeScalar, Radius * sizeScalar);
        }
    }

    public class Bar
    {
        public float Width { get; set; } = 58;
        public float Height { get; set; } = 10;

        public RectangleF GetRectangle(float buttonSize, float sizeScalar)
        {
            return new RectangleF((buttonSize / 2.0f) - (Width * sizeScalar / 2.0f), (buttonSize / 2.0f) - (Height * sizeScalar / 2.0f), Width * sizeScalar, Height * sizeScalar);
        }
    }

    public class ImageRenderer : IDisposable
    {
        protected Image imageRef;
        protected Bitmap background;
        protected Graphics render;

        protected int buttonSize = 72;
        protected float buttonSizeH;
        protected float sizeScalar;

        protected StringFormat stringFormat = new()
        {
            Alignment = StringAlignment.Center,
            LineAlignment = StringAlignment.Center,
            FormatFlags = StringFormatFlags.FitBlackBox
        };

        public ImageRenderer(Image image)
        {
            imageRef = image;
            background = new Bitmap(imageRef);
            render = Graphics.FromImage(background);

            render.SmoothingMode = SmoothingMode.AntiAlias;
            render.InterpolationMode = InterpolationMode.HighQualityBicubic;
            render.PixelOffsetMode = PixelOffsetMode.HighQuality;
            render.CompositingQuality = CompositingQuality.HighQuality;
            render.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
            render.PageUnit = GraphicsUnit.Pixel;

            buttonSize = background.Width;
            buttonSizeH = buttonSize / 2;
            sizeScalar = (float)buttonSize / 72.0f;
        }

        public RectangleF ScaleRectangle(RectangleF rect)
        {
            return new RectangleF(rect.X * sizeScalar, rect.Y * sizeScalar, rect.Width * sizeScalar, rect.Height * sizeScalar);
        }

        public Font ScaleFont(Font font)
        {
            return new Font(font.Name, font.Size * sizeScalar, font.Style);
        }

        public void DrawImage(Image image, RectangleF drawRectangle)
        {
            render.DrawImage(image, ScaleRectangle(drawRectangle));
        }

        public void DrawText(string text, Font drawFont, Color drawColor, RectangleF drawRectangle)
        {
            SolidBrush drawBrush = new (drawColor);
            render.DrawString(text, ScaleFont(drawFont), drawBrush, ScaleRectangle(drawRectangle), stringFormat);
            drawBrush.Dispose();
        }

        public void DrawBox(Color drawColor, float lineSize, RectangleF drawRectangle)
        {
            Pen pen = new(drawColor, lineSize * sizeScalar);
            RectangleF rect = ScaleRectangle(drawRectangle);
            render.DrawRectangle(pen, rect.X, rect.Y, rect.Width, rect.Height);
            pen.Dispose();
        }

        public void Rotate(float angle, PointF offset)
        {
            render.TranslateTransform(buttonSizeH + offset.X , buttonSizeH + offset.Y );
            render.RotateTransform(angle);
            render.TranslateTransform(-(buttonSizeH + offset.X ), -(buttonSizeH + offset.Y ));
        }

        public void DrawArc(Arc drawArc, Color drawColor)
        {
            RectangleF drawRect = drawArc.GetRectangle(buttonSize, sizeScalar);
            
            Pen pen = new(drawColor, drawArc.Width * sizeScalar);
            render.DrawArc(pen, drawRect, drawArc.StartAngle, drawArc.SweepAngle);
            pen.Dispose();
        }

        public void DrawArcIndicator(Arc drawArc, Color drawColor, float size, float value, float minimum, float maximum, bool bottom = false)
        {
            RectangleF drawRect = drawArc.GetRectangle(buttonSize, sizeScalar);
            float angle = (NormalizedRatio(value, minimum, maximum) * drawArc.SweepAngle) + drawArc.StartAngle;
            
            size = (size * sizeScalar) / 2.0f;
            float orgIndX = drawRect.X + drawRect.Width + (bottom ? -size : size);
            float orgIndY = drawRect.Y + drawRect.Width / 2.0f;
            float top = bottom ? -size : size;
            
            PointF[] triangle = {   new PointF(orgIndX - top, orgIndY),
                                    new PointF(orgIndX + top, orgIndY + size),
                                    new PointF(orgIndX + top, orgIndY - size) };

            SolidBrush brush = new(drawColor);
            Rotate(angle, drawArc.Offset);
            render.FillPolygon(brush, triangle);
            Rotate(-angle, drawArc.Offset);
            brush.Dispose();
        }

        public void DrawArcCenterLine(Arc drawArc, Color drawColor, float size)
        {
            RectangleF drawRect = drawArc.GetRectangle(buttonSize, sizeScalar);
            float orgIndX = drawRect.X + drawRect.Width;
            float orgIndY = (drawRect.Y + drawRect.Width / 2.0f);
            float angle = (drawArc.SweepAngle / 2.0f) + drawArc.StartAngle;

            Pen pen = new(drawColor, size * sizeScalar);
            Rotate(angle, drawArc.Offset);
            render.DrawLine(pen, orgIndX - (drawArc.Width * sizeScalar * 0.5f), orgIndY, orgIndX + (drawArc.Width * sizeScalar * 0.5f), orgIndY); ;
            Rotate(-angle, drawArc.Offset);
            pen.Dispose();
        }

        public void DrawArcRanges(Arc drawArc, Color[] colors, float[][] ranges, float minimum, float maximum, bool symm = false)
        {
            if (maximum == 0.0f)
                return;

            RectangleF drawRect = drawArc.GetRectangle(buttonSize, sizeScalar);
            float rangeAngleStart;
            float rangeAngleSweep;
            float fix = 1.0f;
            for (int i = 0; i < ranges.Length; i++)
            {
                rangeAngleStart = NormalizedRatio(ranges[i][0], minimum, maximum) * drawArc.SweepAngle;
                rangeAngleSweep = NormalizedDiffRatio(ranges[i][1], ranges[i][0], minimum, maximum) * drawArc.SweepAngle;   

                Pen pen = new(colors[i], drawArc.Width * sizeScalar);
                render.DrawArc(pen, drawRect, drawArc.StartAngle + rangeAngleStart - fix, rangeAngleSweep + fix);

                if (symm)
                {
                    rangeAngleStart = NormalizedDiffRatio(maximum, ranges[i][1], minimum, maximum) * drawArc.SweepAngle;
                    render.DrawArc(pen, drawRect, drawArc.StartAngle + rangeAngleStart - fix, rangeAngleSweep + fix);
                }

                pen.Dispose();
            }
        }

        public void DrawBar(Color mainColor, Bar drawBar)
        {
            SolidBrush brush = new(mainColor);
            render.FillRectangle(brush, drawBar.GetRectangle(buttonSize, sizeScalar));

            brush.Dispose();
        }

        public void DrawBarCenterLine(Bar drawBar, Color centerColor, float centerSize)
        {
            Pen pen = new(centerColor, centerSize * sizeScalar);
            RectangleF drawParams = drawBar.GetRectangle(buttonSize, sizeScalar);
            float off = (drawParams.Width / 2.0f);//+ 0.5f;
            render.DrawLine(pen, drawParams.X + off, drawParams.Y, drawParams.X + off, drawParams.Y + drawParams.Height);

            pen.Dispose();
        }

        public void DrawBarIndicator(Bar drawBar, Color drawColor, float size, float value, float minimum, float maximum, bool bottom = false)
        {
            if (maximum == 0.0f)
                return;

            size = (size * sizeScalar) / 2.0f;
            RectangleF drawParams = drawBar.GetRectangle(buttonSize, sizeScalar);
            float indX = (drawParams.X + (NormalizedRatio(value, minimum, maximum) * drawParams.Width));
            float indY = (bottom ? drawParams.Y + drawParams.Height : drawParams.Y);
            float top = (bottom ? size * -1.0f : size);
            PointF[] triangle = { new PointF(indX - size, indY - top), new PointF(indX + size, indY - top), new PointF(indX, indY + top) };

            SolidBrush brush = new(drawColor);
            render.FillPolygon(brush, triangle);
            brush.Dispose();
        }

        public void DrawBarRanges(Bar drawBar, Color[] colors, float[][] ranges, float minimum, float maximum, bool symm = false)
        {
            if (maximum == 0.0f)
                return;

            float barW;
            RectangleF drawParams = drawBar.GetRectangle(buttonSize, sizeScalar);
            float fix = 0.5f;
            for (int i = 0; i < ranges.Length; i++)
            {
                barW = NormalizedDiffRatio(ranges[i][1], ranges[i][0], minimum, maximum) * drawParams.Width;

                SolidBrush brush = new(colors[i]);
                render.FillRectangle(brush, drawParams.X + NormalizedRatio(ranges[i][0], minimum, maximum) * drawParams.Width, drawParams.Y, barW + fix, drawParams.Height);

                if (symm)
                    render.FillRectangle(brush, (drawParams.X + NormalizedDiffRatio(maximum, ranges[i][1], minimum, maximum) * drawParams.Width), drawParams.Y, barW + fix, drawParams.Height);

                brush.Dispose();
            }
        }

        protected static float NormalizedDiffRatio(float minuend, float subtrahend, float minimumTotal, float maximumTotal)
        {
            SwapMinMax(ref minimumTotal, ref maximumTotal);

            return Ratio((NormalizedValue(minuend, minimumTotal) - NormalizedValue(subtrahend, minimumTotal)), NormalizedValue(maximumTotal, minimumTotal));
        }

        public static float NormalizedValue(float value, float minimum)
        {
            if (minimum < 0.0f)
                value += Math.Abs(minimum);
            else if (minimum > 0.0f)
                value -= minimum;

            return value;
        }



        protected static float NormalizedRatio(float value, float minimum, float maximum)
        {
            SwapMinMax(ref minimum, ref maximum);

            if (minimum < 0.0f)
            {
                maximum += Math.Abs(minimum);
                value += Math.Abs(minimum);
            }
            else if (minimum > 0.0f)
            {
                maximum -= minimum;
                value -= minimum;
            }

            return Ratio(value, maximum);
        }

        protected static float Ratio(float value, float maximum)
        {
            float ratio = value / maximum;
            if (ratio < 0.0f)
                ratio = 0.0f;
            else if (ratio > 1.0f)
                ratio = 1.0f;

            return ratio;
        }

        protected static void SwapMinMax(ref float minimum, ref float maximum)
        {
            if (minimum > maximum)
            {
                (maximum, minimum) = (minimum, maximum);
            }
        }

        public string RenderImage64()
        {
            string image64 = "";

            using (MemoryStream stream = new())
            {
                background.Save(stream, ImageFormat.Png);
                image64 = Convert.ToBase64String(stream.ToArray());
                stream.Dispose();
            }            

            return image64;
        }

        public void Dispose()
        {
            stringFormat.Dispose();
            render.Dispose();
            background.Dispose();
            imageRef.Dispose();
            GC.SuppressFinalize(this);
        }


    }
}
