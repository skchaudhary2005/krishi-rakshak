import React, { useRef, useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import type { AdvancedDetectionResult } from '../services/advancedMLService';

interface DiseaseVisualizerProps {
  image: string;
  result: AdvancedDetectionResult;
}

/**
 * Component to visualize disease detection results
 * - Displays bounding boxes around diseased regions
 * - Shows severity heatmap
 * - Highlights affected areas
 */
const DiseaseVisualizer: React.FC<DiseaseVisualizerProps> = ({ image, result }) => {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [showHeatmap, setShowHeatmap] = useState(false);

  useEffect(() => {
    drawVisualization();
  }, [image, result, showHeatmap]);

  const drawVisualization = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    const img = new Image();
    img.onload = () => {
      // Set canvas size to match image
      canvas.width = img.width;
      canvas.height = img.height;

      // Draw original image
      ctx.drawImage(img, 0, 0);

      if (showHeatmap && result.heatmapData) {
        // Draw heatmap overlay
        drawHeatmap(ctx, result.heatmapData, img.width, img.height);
      } else {
        // Draw bounding boxes
        drawBoundingBoxes(ctx, result.diseaseRegions);
      }

      // Draw legend
      drawLegend(ctx, img.width, img.height);
    };
    img.src = image;
  };

  const drawBoundingBoxes = (ctx: CanvasRenderingContext2D, regions: any[]) => {
    regions.forEach((region, index) => {
      // Get color based on severity
      const color = getSeverityColor(region.severity);

      // Draw bounding box
      ctx.strokeStyle = color;
      ctx.lineWidth = 4;
      ctx.strokeRect(region.x, region.y, region.width, region.height);

      // Draw semi-transparent overlay
      ctx.fillStyle = `${color}33`; // 20% opacity
      ctx.fillRect(region.x, region.y, region.width, region.height);

      // Draw label
      const label = `${region.severity} (${(region.confidence * 100).toFixed(0)}%)`;
      ctx.font = 'bold 16px Arial';
      ctx.fillStyle = color;
      ctx.strokeStyle = '#000';
      ctx.lineWidth = 3;
      
      // Background for text
      const textWidth = ctx.measureText(label).width;
      ctx.fillStyle = '#000000aa';
      ctx.fillRect(region.x, region.y - 25, textWidth + 10, 25);
      
      // Text
      ctx.fillStyle = '#fff';
      ctx.fillText(label, region.x + 5, region.y - 7);

      // Draw crosshair at center
      const centerX = region.x + region.width / 2;
      const centerY = region.y + region.height / 2;
      ctx.strokeStyle = color;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.moveTo(centerX - 10, centerY);
      ctx.lineTo(centerX + 10, centerY);
      ctx.moveTo(centerX, centerY - 10);
      ctx.lineTo(centerX, centerY + 10);
      ctx.stroke();
    });
  };

  const drawHeatmap = (
    ctx: CanvasRenderingContext2D,
    heatmapData: number[][],
    width: number,
    height: number
  ) => {
    const gridSize = heatmapData.length;
    const cellWidth = width / gridSize;
    const cellHeight = height / gridSize;

    heatmapData.forEach((row, i) => {
      row.forEach((value, j) => {
        // Map value (0-1) to color (green -> yellow -> red)
        const color = getHeatmapColor(value);
        
        ctx.fillStyle = color;
        ctx.fillRect(
          j * cellWidth,
          i * cellHeight,
          cellWidth,
          cellHeight
        );
      });
    });

    // Add semi-transparency overlay to original image
    ctx.globalAlpha = 0.5;
    const img = new Image();
    img.src = image;
    ctx.drawImage(img, 0, 0);
    ctx.globalAlpha = 1.0;
  };

  const drawLegend = (ctx: CanvasRenderingContext2D, width: number, height: number) => {
    // Draw severity legend in top-right corner
    const legendX = width - 200;
    const legendY = 10;
    
    ctx.fillStyle = '#000000cc';
    ctx.fillRect(legendX, legendY, 190, showHeatmap ? 140 : 180);

    ctx.font = 'bold 14px Arial';
    ctx.fillStyle = '#fff';
    ctx.fillText(showHeatmap ? 'Heatmap Scale' : 'Severity Levels', legendX + 10, legendY + 25);

    if (showHeatmap) {
      // Heatmap scale
      const gradient = ctx.createLinearGradient(legendX + 10, legendY + 40, legendX + 170, legendY + 40);
      gradient.addColorStop(0, '#10B981');
      gradient.addColorStop(0.5, '#FCD34D');
      gradient.addColorStop(1, '#EF4444');
      
      ctx.fillStyle = gradient;
      ctx.fillRect(legendX + 10, legendY + 40, 170, 20);
      
      ctx.font = '12px Arial';
      ctx.fillStyle = '#fff';
      ctx.fillText('Healthy', legendX + 10, legendY + 75);
      ctx.fillText('Severe', legendX + 140, legendY + 75);
    } else {
      // Severity boxes
      const severities = [
        { label: 'Early', color: '#FCD34D' },
        { label: 'Moderate', color: '#F59E0B' },
        { label: 'Severe', color: '#EF4444' },
        { label: 'Critical', color: '#991B1B' },
      ];

      severities.forEach((sev, idx) => {
        const y = legendY + 40 + idx * 30;
        ctx.fillStyle = sev.color;
        ctx.fillRect(legendX + 10, y, 20, 20);
        
        ctx.font = '12px Arial';
        ctx.fillStyle = '#fff';
        ctx.fillText(sev.label, legendX + 40, y + 15);
      });
    }
  };

  const getSeverityColor = (severity: string): string => {
    const colors: { [key: string]: string } = {
      'EARLY': '#FCD34D',
      'MODERATE': '#F59E0B',
      'SEVERE': '#EF4444',
      'CRITICAL': '#991B1B',
    };
    return colors[severity] || '#10B981';
  };

  const getHeatmapColor = (value: number): string => {
    // Green (healthy) -> Yellow -> Red (severe)
    if (value < 0.2) return `rgba(16, 185, 129, ${value * 2})`;
    if (value < 0.5) return `rgba(252, 211, 77, ${value})`;
    return `rgba(239, 68, 68, ${value})`;
  };

  return (
    <div className="relative">
      {/* Controls */}
      <div className="mb-4 flex justify-between items-center">
        <h3 className="text-lg font-bold text-gray-800">
          📍 Disease Localization
        </h3>
        <button
          onClick={() => setShowHeatmap(!showHeatmap)}
          className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition text-sm font-semibold"
        >
          {showHeatmap ? '📦 Show Boxes' : '🌡️ Show Heatmap'}
        </button>
      </div>

      {/* Canvas */}
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        className="rounded-xl overflow-hidden shadow-lg border-4 border-blue-200"
      >
        <canvas
          ref={canvasRef}
          className="w-full h-auto"
        />
      </motion.div>

      {/* Region Details */}
      {!showHeatmap && result.diseaseRegions.length > 0 && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="mt-4 p-4 bg-gradient-to-r from-blue-50 to-purple-50 rounded-xl border-2 border-blue-200"
        >
          <h4 className="font-bold text-blue-900 mb-2">
            🎯 Detected Disease Regions: {result.diseaseRegions.length}
          </h4>
          <div className="grid grid-cols-2 gap-2 text-sm">
            {result.diseaseRegions.map((region, index) => (
              <div key={index} className="bg-white p-2 rounded-lg">
                <span className="font-semibold">Region {index + 1}:</span>
                <span
                  className="ml-2 px-2 py-1 rounded text-xs font-bold"
                  style={{ backgroundColor: getSeverityColor(region.severity), color: '#fff' }}
                >
                  {region.severity} ({(region.confidence * 100).toFixed(0)}%)
                </span>
              </div>
            ))}
          </div>
        </motion.div>
      )}

      {/* Heatmap Info */}
      {showHeatmap && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.3 }}
          className="mt-4 p-4 bg-gradient-to-r from-green-50 to-red-50 rounded-xl border-2 border-orange-200"
        >
          <h4 className="font-bold text-orange-900 mb-2">
            🌡️ Severity Heatmap
          </h4>
          <p className="text-sm text-gray-700">
            <span className="font-semibold">Green areas:</span> Healthy tissue<br />
            <span className="font-semibold">Yellow areas:</span> Early disease symptoms<br />
            <span className="font-semibold">Red areas:</span> Severe infection
          </p>
        </motion.div>
      )}
    </div>
  );
};

export default DiseaseVisualizer;